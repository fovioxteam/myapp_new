import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

class VideoCompressor {
  /// 🚀 СУПЕР-БЫСТРОЕ сжатие для соцсетей
  /// Время: 3-5 сек, размер: 5-10 МБ для 15-сек видео
  static Future<File?> compressVideo(
    String inputPath, {
    int maxDimension = 720, // 720p для скорости, 1080p для качества
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // 🔥 Сохраняем пропорции, режем до 720p
      final vfScale =
          "scale='if(gt(iw,ih),min($maxDimension,iw),-2)':'if(gt(iw,ih),-2,min($maxDimension,ih))'";

      // 🔥 ОПТИМИЗИРОВАННАЯ КОМАНДА:
      // - threads 0 (задействуем все ядра)
      // - crf 24 (высокое сжатие)
      // - maxrate 3M (ограничение битрейта)
      // - bufsize 6M (буфер для плавности)
      // - preset ultrafast (максимальная скорость)
      final command =
          '-threads 0 '
          '-i "$inputPath" '
          '-vf "$vfScale" '
          '-c:v libx264 '
          '-crf 24 '
          '-maxrate 3M -bufsize 6M '
          '-preset ultrafast '
          '-pix_fmt yuv420p '
          '-c:a aac -b:a 96k '
          '-movflags +faststart '
          '-y "$outputPath"';

      print('🚀 [FFMPEG] Starting OPTIMIZED compression (720p, crf 24)...');
      final stopwatch = Stopwatch()..start();

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      stopwatch.stop();
      print('⏱️ [FFMPEG] Compression took: ${stopwatch.elapsed.inSeconds} sec');

      if (ReturnCode.isSuccess(returnCode)) {
        final compressedFile = File(outputPath);
        final originalSizeMB =
            (await File(inputPath).length()) / (1024 * 1024);
        final compressedSizeMB =
            (await compressedFile.length()) / (1024 * 1024);

        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('✅ Compression finished');
        print('Original  : ${originalSizeMB.toStringAsFixed(2)} MB');
        print('Compressed: ${compressedSizeMB.toStringAsFixed(2)} MB');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        return compressedFile;
      } else {
        print('❌ [FFMPEG] Compression failed');
        return null;
      }
    } catch (e) {
      print('❌ [FFMPEG] Exception: $e');
      return null;
    }
  }

  /// Генерация превью (БЫСТРО)
  static Future<File?> generateThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final command =
          '-threads 0 '
          '-ss 00:00:00.500 -i "$videoPath" -vframes 1 -q:v 2 -y "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final thumbFile = File(outputPath);
        if (await thumbFile.exists() && await thumbFile.length() > 0) {
          return thumbFile;
        }
      }
      return null;
    } catch (e) {
      print('❌ Thumbnail error: $e');
      return null;
    }
  }

  /// ⏱️ Точное определение длительности видео
  static Future<int> getVideoDurationMs(String videoPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final info = session.getMediaInformation();
      final durationStr = info?.getDuration();
      if (durationStr != null) {
        final seconds = double.tryParse(durationStr) ?? 0.0;
        return (seconds * 1000).toInt(); // 🔥 Исправленный расчет
      }
    } catch (e) {
      print('❌ Duration error: $e');
    }
    return 0;
  }
}