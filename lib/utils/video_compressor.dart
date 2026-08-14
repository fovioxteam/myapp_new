import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

class VideoCompressor {
  /// Сжатие видео с кастомными настройками разрешение / битрейт
  static Future<File?> compressVideo(
    String inputPath, {
    int targetHeight = 720,
    String bitRate = '2.5M',
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Команда FFmpeg:
      // -vf "scale=-2:$targetHeight" с добавлением -pix_fmt yuv420p решает проблему
      // сбоя кодека c2.android.avc.encoder и нулевого размера файла (0.00 MB)
      final command =
          '-i "$inputPath" -vf "scale=trunc(oh*a/2)*2:$targetHeight" -c:v libx264 -pix_fmt yuv420p -b:v $bitRate -c:a aac -b:a 96k -movflags +faststart -y "$outputPath"';

      print('🚀 [FFMPEG] Starting compression...');
      print('🚀 [FFMPEG] Command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final compressedFile = File(outputPath);
        final originalSizeMB =
            (await File(inputPath).length()) / (1024 * 1024);
        final compressedSizeMB =
            (await compressedFile.length()) / (1024 * 1024);

        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('✅ Compression finished');
        print('Original : ${originalSizeMB.toStringAsFixed(2)} MB');
        print('Compressed: ${compressedSizeMB.toStringAsFixed(2)} MB');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        return compressedFile;
      } else {
        final logs = await session.getLogsAsString();
        print('❌ [FFMPEG] Compression failed:\n$logs');
        return null;
      }
    } catch (e) {
      print('❌ [FFMPEG] Exception during video compression: $e');
      return null;
    }
  }

  /// Генерация превью (Thumbnail) первого кадра через FFmpeg
  static Future<File?> generateThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Извлекаем кадр на 0.5 секунде видео
      final command =
          '-ss 00:00:00.500 -i "$videoPath" -vframes 1 -q:v 2 -y "$outputPath"';

      print('🚀 [FFMPEG] Generating thumbnail...');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final thumbFile = File(outputPath);
        if (await thumbFile.exists() && await thumbFile.length() > 0) {
          print('✅ [FFMPEG] Thumbnail generated: ${thumbFile.path}');
          return thumbFile;
        }
      }

      print('❌ [FFMPEG] Thumbnail generation failed');
      return null;
    } catch (e) {
      print('❌ [FFMPEG] Exception during thumbnail generation: $e');
      return null;
    }
  }

  /// Получение длительности видео в миллисекундах (замена VideoCompress.getMediaInfo)
  static Future<int> getVideoDurationMs(String videoPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final info = session.getMediaInformation();
      final durationStr = info?.getDuration();

      if (durationStr != null) {
        final durationInSeconds = double.tryParse(durationStr) ?? 0.0;
        return (durationInSeconds * 1000).toInt();
      }
    } catch (e) {
      print('❌ [FFPROBE] Failed to get video duration: $e');
    }
    return 0;
  }
}