// lib/utils/video_compressor.dart

import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoCompressor {
  /// Качественное сжатие видео
  static Future<File> compressVideo(File videoFile) async {
    try {
      print("🎬 [FFMPEG] Starting compression...");

      final tempDir = await getTemporaryDirectory();

      final outputPath =
          "${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4";

      final command = '''
-i "${videoFile.path}"
-map_metadata 0
-vf "scale='if(gt(iw,720),720,iw)':-2:flags=lanczos,fps=min(30\\,fps)"
-c:v libx264
-profile:v high
-level:v 4.1
-preset slow
-crf 20
-x264-params ref=4:bframes=4:subme=9:me=umh:trellis=2:rc-lookahead=50:direct=auto:deblock=-1,-1
-pix_fmt yuv420p
-movflags +faststart
-c:a aac
-b:a 128k
-ar 44100
-ac 2
-max_muxing_queue_size 1024
-y
"$outputPath"
''';

      print(command);

      final session = await FFmpegKit.execute(command);

      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getLogsAsString();
        print("❌ FFmpeg Error:");
        print(logs);
        return videoFile;
      }

      final outputFile = File(outputPath);

      if (!await outputFile.exists()) {
        print("❌ Output file missing");
        return videoFile;
      }

      final originalSize = await videoFile.length();
      final compressedSize = await outputFile.length();

      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      print("✅ Compression finished");
      print(
          "Original : ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB");
      print(
          "Compressed: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB");
      print(
          "Saved ${(100 - compressedSize / originalSize * 100).toStringAsFixed(1)}%");
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

      return outputFile;
    } catch (e) {
      print("❌ Compression exception:");
      print(e);
      return videoFile;
    }
  }

  /// Генерация превью
  static Future<File?> getFileThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();

      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        quality: 90,
        maxWidth: 720,
      );

      if (thumbPath == null) {
        return null;
      }

      return File(thumbPath);
    } catch (e) {
      print("Thumbnail error: $e");
      return null;
    }
  }
}