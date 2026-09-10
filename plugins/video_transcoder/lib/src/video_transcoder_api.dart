import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class VideoTranscoderException implements Exception {
  final String code;
  final String message;

  VideoTranscoderException(this.code, this.message);

  @override
  String toString() => 'VideoTranscoderException($code): $message';
}

class TranscodeResult {
  final String path;
  final bool wasTranscoded;

  TranscodeResult({required this.path, required this.wasTranscoded});
}

class VideoTranscoder {
  static const MethodChannel _method = MethodChannel('video_transcoder/methods');
  static const EventChannel _progress = EventChannel('video_transcoder/events');

  /// Транскодер HDR → SDR H.264 (720p).
  static Future<TranscodeResult> transcodeForUpload(
    File rawFile, {
    int maxOriginalSizeBytes = 15 * 1024 * 1024,
    void Function(double progress)? onProgress,
  }) async {
    if (!await rawFile.exists()) {
      throw VideoTranscoderException('FILE_NOT_FOUND', 'Input file does not exist');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${tempDir.path}/transcoded_$timestamp.mp4';

    StreamSubscription? progressSub;
    if (onProgress != null) {
      progressSub = _progress.receiveBroadcastStream().listen((event) {
        if (event is double) {
          onProgress(event.clamp(0.0, 1.0));
        } else if (event is num) {
          onProgress(event.toDouble().clamp(0.0, 1.0));
        }
      });
    }

    try {
      final Map<dynamic, dynamic>? result = await _method.invokeMapMethod(
        'transcode',
        {
          'inputPath': rawFile.path,
          'outputPath': outputPath,
          'maxOriginalSizeBytes': maxOriginalSizeBytes,
        },
      );

      if (result == null) {
        throw VideoTranscoderException('NULL_RESULT', 'Native returned null');
      }

      final path = result['path'] as String?;
      final wasTranscoded = result['wasTranscoded'] as bool? ?? false;

      if (path == null || path.isEmpty) {
        throw VideoTranscoderException('EMPTY_PATH', 'Native returned empty path');
      }

      final outputFile = File(path);
      if (!await outputFile.exists()) {
        throw VideoTranscoderException('FILE_MISSING', 'Output file not found');
      }

      if (await outputFile.length() == 0) {
        throw VideoTranscoderException('EMPTY_FILE', 'Output file is empty');
      }

      return TranscodeResult(path: path, wasTranscoded: wasTranscoded);
    } on PlatformException catch (e) {
      throw VideoTranscoderException(e.code, e.message ?? 'Native transcoding failed');
    } on MissingPluginException {
      rethrow;
    } finally {
      await progressSub?.cancel();
    }
  }

  /// Отмена текущего процесса транскодирования.
  static Future<void> cancel() async {
    try {
      await _method.invokeMethod('cancel');
    } on PlatformException catch (e) {
      throw VideoTranscoderException(e.code, e.message ?? 'Failed to cancel transcoding');
    }
  }

  /// Быстрая генерация обложки из оригинала через AVAssetImageGenerator.
  static Future<File?> generateThumbnail(
    File rawFile, {
    int timeMs = 500,
  }) async {
    if (!await rawFile.exists()) {
      return null;
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${tempDir.path}/thumb_$timestamp.jpg';

    try {
      final String? resultPath = await _method.invokeMethod(
        'getVideoThumbnail',
        {
          'inputPath': rawFile.path,
          'outputPath': outputPath,
          'timeMs': timeMs,
        },
      );

      if (resultPath == null || resultPath.isEmpty) {
        return null;
      }

      final outputFile = File(resultPath);
      if (!await outputFile.exists() || await outputFile.length() == 0) {
        return null;
      }

      return outputFile;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }
}