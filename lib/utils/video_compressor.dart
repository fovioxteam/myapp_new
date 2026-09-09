import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/statistics.dart';

class VideoCompressor {
  static const int maxOriginalSizeBytes = 15 * 1024 * 1024;
  static const int maxDimension = 1920;
  static const int crf = 20;
  static const String preset = 'medium';

  // ===========================================================================
  // VIDEO DURATION
  // ===========================================================================

  static Future<int?> getVideoDurationMs(File file) async {
    try {
      if (!await file.exists()) return null;

      final session = await FFmpegKit.execute(
        '-v error '
        '-show_entries format=duration '
        '-of default=noprint_wrappers=1:nokey=1 '
        '"${file.path}"',
      );

      final logs = await session.getLogs();

      for (final log in logs) {
        final value = double.tryParse(log.getMessage().trim());

        if (value != null) {
          return (value * 1000).round();
        }
      }
    } catch (e) {
      debugPrint('❌ Duration error: $e');
    }

    return null;
  }

  // ===========================================================================
  // THUMBNAIL
  // ===========================================================================

  static Future<File?> generateThumbnail(File inputFile) async {
    try {
      if (!await inputFile.exists()) {
        debugPrint('❌ Thumbnail: input file does not exist');
        return null;
      }

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
        "scale='if(gt(iw,ih),min(720,iw),-2)':"
            "'if(gt(iw,ih),-2,min(720,ih))':"
            "flags=lanczos,format=yuv420p",

        '-q:v',
        '2',

        outputPath,
      ];

      debugPrint('🎬 Generating thumbnail...');
      debugPrint(arguments.join(' '));

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
        (log) {
          final message = log.getMessage();
          final lower = message.toLowerCase();

          if (lower.contains('error') ||
              lower.contains('failed') ||
              lower.contains('invalid') ||
              lower.contains('unsupported')) {
            debugPrint('❌ Thumbnail FFmpeg: $message');
          }
        },
      );

      final returnCode = await completer.future;

      if (!ReturnCode.isSuccess(returnCode)) {
        debugPrint(
          '❌ Thumbnail failed: ${returnCode?.getValue()}',
        );

        if (await outputFile.exists()) {
          await outputFile.delete();
        }

        return null;
      }

      if (!await outputFile.exists()) {
        debugPrint('❌ Thumbnail output does not exist');
        return null;
      }

      final size = await outputFile.length();

      if (size == 0) {
        await outputFile.delete();
        return null;
      }

      debugPrint(
        '✅ Thumbnail generated: ${outputFile.path} '
        '(${(size / 1024).toStringAsFixed(1)} KB)',
      );

      return outputFile;
    } catch (e, stack) {
      debugPrint('❌ Thumbnail error: $e');
      debugPrint('$stack');
      return null;
    }
  }

  // ===========================================================================
  // SCALE
  // ===========================================================================

  static String _buildVideoFilter() {
    return "scale="
        "'if(gt(iw,ih),min($maxDimension,iw),-2)':"
        "'if(gt(iw,ih),-2,min($maxDimension,ih))':"
        "flags=lanczos,format=yuv420p";
  }

  // ===========================================================================
  // COMPRESS VIDEO
  // ===========================================================================

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

    debugPrint('');
    debugPrint('🎬 Video compression started');
    debugPrint(
      '📦 Original: '
      '${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB',
    );

    // Files <= 15 MB are uploaded as-is.
    if (originalSize <= maxOriginalSizeBytes) {
      debugPrint('✅ File <= 15 MB, compression skipped');
      onProgress?.call(1.0);
      return inputFile;
    }

    final tempDir = await getTemporaryDirectory();

    final outputPath =
        '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final outputFile = File(outputPath);

    final durationMs = await getVideoDurationMs(inputFile);

    final arguments = <String>[
      '-y',

      '-i',
      inputFile.path,

      '-map',
      '0:v:0',

      '-map',
      '0:a:0?',

      '-vf',
      _buildVideoFilter(),

      '-c:v',
      'libx264',

      '-preset',
      preset,

      '-crf',
      '$crf',

      '-pix_fmt',
      'yuv420p',

      '-color_primaries',
      'bt709',

      '-color_trc',
      'bt709',

      '-colorspace',
      'bt709',

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

    debugPrint('🎥 FFmpeg compression started');

    final completer = Completer<ReturnCode?>();

    int lastPercent = -1;

    try {
      await FFmpegKit.executeWithArgumentsAsync(
        arguments,

        // Completion
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

        // Logs
        (log) {
          final message = log.getMessage();
          final lower = message.toLowerCase();

          if (lower.contains('error') ||
              lower.contains('failed') ||
              lower.contains('invalid') ||
              lower.contains('unsupported')) {
            debugPrint('❌ FFmpeg: $message');
          }
        },

        // Progress
        (Statistics statistics) {
          if (durationMs == null || durationMs <= 0) return;

          final timeMs = statistics.getTime();

          if (timeMs <= 0) return;

          var progress = timeMs / durationMs;

          if (progress > 1) progress = 1;
          if (progress < 0) progress = 0;

          final percent = (progress * 100).round();

          if (percent != lastPercent) {
            lastPercent = percent;

            debugPrint('📊 Compression: $percent%');

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

    // IMPORTANT:
    // executeWithArgumentsAsync() returns before FFmpeg finishes.
    // We wait for the completion callback here.
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

    debugPrint('');
    debugPrint('📦 Compression finished');
    debugPrint(
      '📦 Original: '
      '${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB',
    );
    debugPrint(
      '📦 Compressed: '
      '${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB',
    );

    if (compressedSize >= originalSize) {
      await outputFile.delete();

      throw Exception(
        'Compressed video is not smaller than original.',
      );
    }

    onProgress?.call(1.0);

    debugPrint(
      '✅ Compression success: ${outputFile.path}',
    );

    return outputFile;
  }
}