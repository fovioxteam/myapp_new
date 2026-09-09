import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/statistics.dart';

class VideoCompressor {
  static const int maxOriginalSizeBytes = 15 * 1024 * 1024;
  static const int maxDimension = 1920;
  static const int crf = 20;
  static const String preset = 'fast';

  static bool? _hasZscale;
  static bool? _hasTonemap;
  static bool? _hasColorspace;

  static Future<void> _checkFFmpegCapabilities() async {
    if (_hasZscale != null &&
        _hasTonemap != null &&
        _hasColorspace != null) {
      return;
    }

    try {
      final session = await FFmpegKit.execute('-filters');
      final logs = await session.getLogs();
      final text = logs.map((e) => e.getMessage().toLowerCase()).join('\n');

      _hasZscale = RegExp(r'\bzscale\b').hasMatch(text);
      _hasTonemap = RegExp(r'\btonemap\b').hasMatch(text);
      _hasColorspace = RegExp(r'\bcolorspace\b').hasMatch(text);
    } catch (_) {
      _hasZscale = false;
      _hasTonemap = false;
      _hasColorspace = false;
    }
  }

  static Future<String> _getProbeOutput(File file) async {
    try {
      final session = await FFprobeKit.getMediaInformation(file.path);

      final output = await session.getOutput();

      if (output != null && output.isNotEmpty) {
        return output.toLowerCase();
      }

      final logs = await session.getLogs();

      return logs.map((e) => e.getMessage()).join('\n').toLowerCase();
    } catch (_) {
      return '';
    }
  }

  static Future<bool> isHdrVideo(File file) async {
    if (!await file.exists()) {
      return false;
    }

    final text = await _getProbeOutput(file);

    if (text.isEmpty) {
      return false;
    }

    return text.contains('dvhe') ||
        text.contains('dvh1') ||
        text.contains('dovi') ||
        text.contains('bt2020') ||
        text.contains('arib-std-b67') ||
        text.contains('smpte2084') ||
        text.contains('display primary') ||
        text.contains('mastering display');
  }

  static Future<int?> getVideoDurationMs(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }

      final session = await FFprobeKit.getMediaInformation(file.path);
      final info = session.getMediaInformation();
      final duration = info?.getDuration();

      if (duration != null) {
        final seconds = double.tryParse(duration);

        if (seconds != null && seconds > 0) {
          return (seconds * 1000).round();
        }
      }
    } catch (_) {}

    return null;
  }

  static Future<String> _buildVideoFilter({
    required bool isHdr,
    required int targetDimension,
  }) async {
    await _checkFFmpegCapabilities();

    final scale =
        "scale='if(gt(iw,ih),min($targetDimension,iw),-2)':"
        "'if(gt(iw,ih),-2,min($targetDimension,ih))':"
        "flags=lanczos";

    if (!isHdr) {
      return '$scale,format=yuv420p';
    }

    if (_hasZscale == true && _hasTonemap == true) {
      return 'zscale=t=linear:npl=100,'
          'tonemap=mobius,'
          'zscale=p=bt709:t=bt709:m=bt709,'
          '$scale,'
          'format=yuv420p';
    }

    if (_hasTonemap == true && _hasColorspace == true) {
      return 'tonemap=mobius,'
          'colorspace=bt709:'
          'iall=bt2020:'
          'itrc=arib-std-b67:'
          'iprimaries=bt2020,'
          '$scale,'
          'format=yuv420p';
    }

    throw Exception(
      'HDR video detected, but required FFmpeg HDR filters are unavailable.',
    );
  }

  static Future<File?> generateThumbnail(File inputFile) async {
    try {
      if (!await inputFile.exists()) {
        return null;
      }

      final isHdr = await isHdrVideo(inputFile);

      final filter = await _buildVideoFilter(
        isHdr: isHdr,
        targetDimension: 720,
      );

      final tempDir = await getTemporaryDirectory();

      final outputPath =
          '${tempDir.path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final outputFile = File(outputPath);

      final arguments = <String>[
        '-y',
        '-ss',
        '1',
        '-i',
        inputFile.path,
        '-frames:v',
        '1',
        '-vf',
        filter,
        '-q:v',
        '2',
        outputPath,
      ];

      final completer = Completer<ReturnCode?>();

      await FFmpegKit.executeWithArgumentsAsync(
        arguments,
        (session) async {
          try {
            final code = await session.getReturnCode();

            if (!completer.isCompleted) {
              completer.complete(code);
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        },
      );

      final returnCode = await completer.future;

      if (!ReturnCode.isSuccess(returnCode) ||
          !await outputFile.exists()) {
        if (await outputFile.exists()) {
          await outputFile.delete();
        }

        return null;
      }

      final size = await outputFile.length();

      if (size <= 0) {
        await outputFile.delete();
        return null;
      }

      return outputFile;
    } catch (_) {
      return null;
    }
  }

  static Future<File> compressVideo(
    File inputFile, {
    void Function(double progress)? onProgress,
  }) async {
    if (!await inputFile.exists()) {
      throw Exception(
        'Input video does not exist: ${inputFile.path}',
      );
    }

    final originalSize = await inputFile.length();

    if (originalSize <= maxOriginalSizeBytes) {
      onProgress?.call(1.0);
      return inputFile;
    }

    final isHdr = await isHdrVideo(inputFile);

    final filter = await _buildVideoFilter(
      isHdr: isHdr,
      targetDimension: maxDimension,
    );

    final durationMs = await getVideoDurationMs(inputFile);

    final tempDir = await getTemporaryDirectory();

    final outputPath =
        '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final outputFile = File(outputPath);

    final arguments = <String>[
      '-y',
      '-i',
      inputFile.path,
      '-map',
      '0:v:0',
      '-map',
      '0:a:0?',
      '-vf',
      filter,
      '-c:v',
      'libx264',
      '-preset',
      preset,
      '-crf',
      '$crf',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      '-ac',
      '2',
      '-movflags',
      '+faststart',
      '-map_metadata',
      '-1',
      '-sn',
      '-dn',
      outputPath,
    ];

    final completer = Completer<ReturnCode?>();
    int lastPercent = -1;

    try {
      await FFmpegKit.executeWithArgumentsAsync(
        arguments,
        (session) async {
          try {
            final code = await session.getReturnCode();

            if (!completer.isCompleted) {
              completer.complete(code);
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        },
        null,
        (Statistics statistics) {
          if (durationMs == null || durationMs <= 0) {
            return;
          }

          final timeMs = statistics.getTime();

          if (timeMs <= 0) {
            return;
          }

          final progress =
              (timeMs / durationMs).clamp(0.0, 1.0).toDouble();

          final percent = (progress * 100).round();

          if (percent != lastPercent) {
            lastPercent = percent;
            onProgress?.call(progress);
          }
        },
      );
    } catch (e) {
      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      throw Exception(
        'Failed to start video compression: $e',
      );
    }

    ReturnCode? returnCode;

    try {
      returnCode = await completer.future;
    } catch (e) {
      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      throw Exception(
        'Video compression failed: $e',
      );
    }

    if (!ReturnCode.isSuccess(returnCode)) {
      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      throw Exception(
        'Video compression failed. '
        'FFmpeg code: ${returnCode?.getValue()}',
      );
    }

    if (!await outputFile.exists()) {
      throw Exception(
        'FFmpeg succeeded but output file does not exist.',
      );
    }

    final compressedSize = await outputFile.length();

    if (compressedSize <= 0) {
      await outputFile.delete();

      throw Exception(
        'Compressed video is empty.',
      );
    }

    if (compressedSize >= originalSize) {
      await outputFile.delete();

      throw Exception(
        'Compressed video is not smaller than original.',
      );
    }

    onProgress?.call(1.0);

    return outputFile;
  }
}