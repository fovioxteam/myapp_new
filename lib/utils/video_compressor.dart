// lib/utils/video_compressor.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';

class VideoCompressor {
  static const int maxOriginalSizeBytes = 15 * 1024 * 1024;
  static const int maxDimension = 1920;

  static const int crf = 20;
  static const String preset = 'fast';

  static bool _capabilitiesChecked = false;
  static bool _hasZscale = false;
  static bool _hasTonemap = false;

  // ============================================================
  // PUBLIC
  // ============================================================

  static Future<int?> getVideoDurationMs(File file) async {
    try {
      if (!await file.exists()) return null;
      final session = await FFprobeKit.getMediaInformation(file.path);
      final duration = session.getMediaInformation()?.getDuration();
      if (duration == null) return null;
      final seconds = double.tryParse(duration);
      if (seconds == null || seconds <= 0) return null;
      return (seconds * 1000).round();
    } catch (_) {
      return null;
    }
  }

  static Future<File?> generateThumbnail(File inputFile, {int? timeMs}) async {
    if (!await inputFile.exists()) return null;
    await _checkCapabilities();
    final isHdr = await _isHdrVideo(inputFile);

    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final seekSeconds = ((timeMs ?? 1000) / 1000.0).clamp(0.0, 10.0);

    final filter = _buildVideoFilter(isHdr: isHdr, targetDimension: 720);
    if (filter == null) return null;

    final arguments = <String>[
      '-y',
      '-ss', seekSeconds.toStringAsFixed(3),
      '-i', inputFile.path,
      '-map', '0:v:0',
      '-frames:v', '1',
      '-vf', filter,
      '-q:v', '2',
      '-an', '-sn', '-dn',
      '-map_metadata', '-1',
      outputPath,
    ];

    final returnCode = await _runFFmpeg(arguments);
    if (!ReturnCode.isSuccess(returnCode)) {
      await _deleteQuietly(outputPath);
      return null;
    }

    final outputFile = File(outputPath);
    if (!await outputFile.exists() || await outputFile.length() <= 0) return null;
    return outputFile;
  }

  static Future<File?> compressVideo(File inputFile) async {
    if (!await inputFile.exists()) return null;
    final originalSize = await inputFile.length();
    await _checkCapabilities();
    final isHdr = await _isHdrVideo(inputFile);

    // Маленькие SDR файлы оставляем как есть
    if (!isHdr && originalSize <= maxOriginalSizeBytes) {
      return inputFile;
    }

    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final filter = _buildVideoFilter(isHdr: isHdr, targetDimension: maxDimension);
    if (filter == null) return null;

    final arguments = <String>[
      '-y',
      '-i', inputFile.path,

      '-map', '0:v:0',
      '-map', '0:a:0?',
      '-sn', '-dn',
      '-map_metadata', '-1',
      '-map_chapters', '-1',

      '-vf', filter,
      '-c:v', 'libx264',
      '-preset', preset,
      '-crf', crf.toString(),
      '-pix_fmt', 'yuv420p',

      // 🔥 Корректный цветовой диапазон (tv / limited range) для стандартного видеоконтента
      '-color_range', 'tv',
      '-colorspace', 'bt709',
      '-color_primaries', 'bt709',
      '-color_trc', 'bt709',

      '-c:a', 'aac',
      '-b:a', '128k',
      '-ar', '48000',

      '-movflags', '+faststart',
      outputPath,
    ];

    final returnCode = await _runFFmpeg(arguments);
    if (!ReturnCode.isSuccess(returnCode)) {
      await _deleteQuietly(outputPath);
      return null;
    }

    final outputFile = File(outputPath);
    if (!await outputFile.exists()) return null;
    final outputSize = await outputFile.length();
    if (outputSize <= 0) return null;

    if (!isHdr && outputSize >= originalSize) {
      await _deleteQuietly(outputPath);
      return inputFile;
    }

    return outputFile;
  }

  // ============================================================
  // FFMPEG CAPABILITIES
  // ============================================================

  static Future<void> _checkCapabilities() async {
    if (_capabilitiesChecked) return;
    _capabilitiesChecked = true;
    try {
      final session = await FFmpegKit.execute('-filters');
      final output = (await session.getOutput()) ?? '';
      final logs = output.toLowerCase();
      _hasZscale = logs.contains('zscale');
      _hasTonemap = logs.contains('tonemap');
    } catch (_) {
      _hasZscale = false;
      _hasTonemap = false;
    }
  }

  // ============================================================
  // HDR DETECTION
  // ============================================================

  static Future<bool> _isHdrVideo(File file) async {
    try {
      final session = await FFprobeKit.getMediaInformation(file.path);
      final output = ((await session.getOutput()) ?? '').toLowerCase();

      if (output.contains('arib-std-b67') || output.contains('smpte2084')) return true;
      final bt2020 = output.contains('bt2020');
      final tenBit = output.contains('yuv420p10') || output.contains('p010');
      if (bt2020 && tenBit) return true;
      if (output.contains('dolby vision') || output.contains('dvhe.') || output.contains('dvh1.')) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // VIDEO FILTER
  // ============================================================

  static String? _buildVideoFilter({
    required bool isHdr,
    required int targetDimension,
  }) {
    final parts = <String>[];

    // HDR → SDR fallback (теперь работает полноценно с full_gpl)
    if (isHdr) {
      if (_hasZscale && _hasTonemap) {
        parts.add('zscale=t=linear:npl=100');
        parts.add('tonemap=mobius:desat=0');
        parts.add('zscale=p=bt709:t=bt709:m=bt709');
      } else {
        debugPrint('⚠️ [FFmpeg] Zscale/Tonemap unavailable, using basic HDR->SDR fallback');
      }
    }

    // 🔥 Идеальный пропорциональный единый scale: вписывает в квадрат, сохраняет ориентацию и делает размеры чётными
    parts.add(
      'scale='
      '${targetDimension}:${targetDimension}:'
      'force_original_aspect_ratio=decrease:'
      'force_divisible_by=2',
    );

    parts.add('setsar=1');
    parts.add('format=yuv420p');

    return parts.join(',');
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static Future<ReturnCode?> _runFFmpeg(List<String> arguments) async {
    final completer = Completer<ReturnCode?>();
    await FFmpegKit.executeWithArgumentsAsync(arguments, (session) async {
      final returnCode = await session.getReturnCode();
      if (!completer.isCompleted) completer.complete(returnCode);
    });
    return completer.future;
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}