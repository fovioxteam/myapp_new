// lib/utils/video_compressor.dart

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_https_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https_gpl/return_code.dart';

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

  /// Возвращает длительность видео в миллисекундах.
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

  /// Извлекает кадр из видео и сохраняет как JPEG.
  ///
  /// Для HDR-видео сначала конвертирует поток в SDR BT709,
  /// потому что прямой захват кадра из Dolby Vision / HLG
  /// не работает на мобильных платформах.
  static Future<File?> generateThumbnail(
    File inputFile, {
    int? timeMs,
  }) async {
    if (!await inputFile.exists()) return null;

    await _checkCapabilities();

    final isHdr = await _isHdrVideo(inputFile);

    final tempDir = await getTemporaryDirectory();

    final outputPath =
        '${tempDir.path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final seekSeconds = ((timeMs ?? 1000) / 1000.0).clamp(0.0, 10.0);

    final filter = _buildVideoFilter(
      isHdr: isHdr,
      targetDimension: 720,
    );

    if (filter == null) return null;

    final arguments = <String>[
      '-y',
      '-ss', seekSeconds.toStringAsFixed(3),
      '-i', inputFile.path,
      '-map', '0:v:0',
      '-frames:v', '1',
      '-vf', filter,
      '-q:v', '2',
      '-an',
      '-sn',
      '-dn',
      '-map_metadata', '-1',
      outputPath,
    ];

    final returnCode = await _runFFmpeg(arguments);

    if (!ReturnCode.isSuccess(returnCode)) {
      await _deleteQuietly(outputPath);
      return null;
    }

    final outputFile = File(outputPath);

    if (!await outputFile.exists()) return null;
    if (await outputFile.length() <= 0) return null;

    return outputFile;
  }

  /// Сжимает видео и конвертирует HDR → SDR (BT709).
  ///
  /// Возвращает:
  /// - сжатый файл при успехе
  /// - исходный файл, если сжатие не имеет смысла (SDR, уже маленький)
  /// - `null`, если HDR-видео не удалось сконвертировать
  static Future<File?> compressVideo(File inputFile) async {
    if (!await inputFile.exists()) return null;

    final originalSize = await inputFile.length();

    await _checkCapabilities();

    final isHdr = await _isHdrVideo(inputFile);

    // SDR-файл уже достаточно маленький → не трогаем.
    // HDR-файл всегда конвертируем, независимо от размера.
    if (!isHdr && originalSize <= maxOriginalSizeBytes) {
      return inputFile;
    }

    final tempDir = await getTemporaryDirectory();

    final outputPath =
        '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final filter = _buildVideoFilter(
      isHdr: isHdr,
      targetDimension: maxDimension,
    );

    if (filter == null) return null;

    final arguments = <String>[
      '-y',

      '-i', inputFile.path,

      // Явный маппинг: только первый видео и первый аудио поток.
      '-map', '0:v:0',
      '-map', '0:a:0?',

      // Убираем субтитры/данные и метаданные исходника.
      '-sn',
      '-dn',
      '-map_metadata', '-1',
      '-map_chapters', '-1',

      // Видео.
      '-vf', filter,
      '-c:v', 'libx264',
      '-preset', preset,
      '-crf', crf.toString(),
      '-pix_fmt', 'yuv420p',

      // Форсируем SDR BT709 на выходе.
      '-color_range', 'tv',
      '-colorspace', 'bt709',
      '-color_primaries', 'bt709',
      '-color_trc', 'bt709',

      // Аудио.
      '-c:a', 'aac',
      '-b:a', '128k',
      '-ar', '48000',

      // MP4.
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

    // Для SDR: если сжатие не уменьшило файл — возвращаем оригинал.
    // Для HDR: оригинал возвращать нельзя, он останется Dolby Vision.
    if (!isHdr && outputSize >= originalSize) {
      await _deleteQuietly(outputPath);
      return inputFile;
    }

    // Проверяем, что HDR реально ушёл.
    final colorOk = await _verifyOutputColor(outputFile);

    if (!colorOk) {
      await _deleteQuietly(outputPath);
      return null;
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

      if (output.contains('arib-std-b67')) return true; // HLG
      if (output.contains('smpte2084')) return true;    // PQ

      final bt2020 =
          output.contains('bt2020') ||
          output.contains('bt2020nc') ||
          output.contains('bt2020ncl');

      final tenBit =
          output.contains('yuv420p10') ||
          output.contains('yuv422p10') ||
          output.contains('yuv444p10') ||
          output.contains('p010');

      if (bt2020 && tenBit) return true;

      if (output.contains('dolby vision') ||
          output.contains('dolby-vision') ||
          output.contains('dvhe.') ||
          output.contains('dvh1.')) {
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
    final scale =
        'scale='
        'w=min($targetDimension\\,iw):'
        'h=min($targetDimension\\,ih):'
        'force_original_aspect_ratio=decrease:'
        'force_divisible_by=2';

    // SDR — просто ресайз и приведение к 8-bit yuv420p.
    if (!isHdr) {
      return '$scale,format=yuv420p';
    }

    // HDR — только через zscale + tonemap.
    // Без zscale честный tone-mapping сделать нельзя.
    if (_hasZscale && _hasTonemap) {
      return [
        'zscale=t=linear:npl=100',
        'tonemap=mobius:desat=0',
        'zscale=p=bt709:t=bt709:m=bt709',
        scale,
        'format=yuv420p',
      ].join(',');
    }

    return null;
  }

  // ============================================================
  // VERIFY OUTPUT COLOR
  // ============================================================

  static Future<bool> _verifyOutputColor(File outputFile) async {
    try {
      final session = await FFprobeKit.getMediaInformation(outputFile.path);
      final output = ((await session.getOutput()) ?? '').toLowerCase();

      final hasBt2020 =
          output.contains('bt2020') ||
          output.contains('bt2020nc') ||
          output.contains('bt2020ncl');

      final hasHlg = output.contains('arib-std-b67');
      final hasPq = output.contains('smpte2084');

      final hasTenBit =
          output.contains('yuv420p10') ||
          output.contains('yuv422p10') ||
          output.contains('yuv444p10') ||
          output.contains('p010');

      final hasBt709 = output.contains('bt709');

      final hasYuv420 =
          output.contains('yuv420p') &&
          !output.contains('yuv420p10');

      if (hasHlg || hasPq || hasTenBit) return false;
      if (hasBt2020) return false;
      if (!hasBt709) return false;
      if (!hasYuv420) return false;

      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Запускает FFmpeg и ждёт завершения.
  /// Возвращает ReturnCode или null при ошибке.
  static Future<ReturnCode?> _runFFmpeg(List<String> arguments) async {
    final completer = Completer<ReturnCode?>();

    await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (session) async {
        final returnCode = await session.getReturnCode();
        if (!completer.isCompleted) {
          completer.complete(returnCode);
        }
      },
    );

    return completer.future;
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}