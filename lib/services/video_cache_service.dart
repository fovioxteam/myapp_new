// lib/services/video_cache_service.dart

import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';

class VideoCacheService {
  static final VideoCacheService _instance = VideoCacheService._internal();
  factory VideoCacheService() => _instance;
  VideoCacheService._internal();

  final CacheManager _cacheManager = CacheManager(
    Config(
      'video_cache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 50,
      repo: JsonCacheInfoRepository(
        databaseName: 'video_cache.db',
      ),
      fileService: HttpFileService(),
    ),
  );

  final Map<String, bool> _downloadingMap = {};
  final Map<String, DateTime> _downloadStartTime = {};

  /// 📥 Фоновое скачивание видео в кеш (предзагрузка)
  Future<void> preCacheVideo(String url) async {
    if (_downloadingMap[url] == true) {
      print('⏳ [VIDEO CACHE] Already downloading: $url');
      return;
    }

    try {
      _downloadingMap[url] = true;
      _downloadStartTime[url] = DateTime.now();

      print('📥 [VIDEO CACHE] Starting pre-cache: $url');

      final file = await _cacheManager.getSingleFile(url);

      if (await file.exists()) {
        final size = await file.length();
        final sizeInMb = (size / (1024 * 1024)).toStringAsFixed(2);
        final startTime = _downloadStartTime[url];
        final duration = startTime != null
            ? DateTime.now().difference(startTime).inSeconds
            : 0;

        print('✅ [VIDEO CACHE] Pre-cached: $url (${sizeInMb}MB, ${duration}s)');
      }
    } catch (e) {
      print('❌ [VIDEO CACHE] Pre-cache error: $e');
    } finally {
      _downloadingMap[url] = false;
      _downloadStartTime.remove(url);
    }
  }

  /// 📹 Получение готового инициализированного контроллера.
  /// Сначала ищет локальный файл (быстрый старт), если файла нет — берет из сети,
  /// не дублируя фоновое скачивание (чтобы не забивать интернет-канал).
  Future<VideoPlayerController> getController(String url) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(url);

      if (fileInfo != null && await fileInfo.file.exists()) {
        final size = await fileInfo.file.length();
        final sizeInMb = (size / (1024 * 1024)).toStringAsFixed(2);
        print('⚡ [VIDEO CACHE] Playing from LOCAL CACHE: $url (${sizeInMb}MB)');

        final controller = VideoPlayerController.file(fileInfo.file);
        await controller.initialize();
        // 🔥 ВКЛЮЧАЕМ ЗВУК ДЛЯ КЕШИРОВАННОГО ВИДЕО
        await controller.setVolume(1.0);
        return controller;
      }
    } catch (e) {
      print('⚠️ [VIDEO CACHE] Error reading cache, fallback to network: $e');
    }

    print('🌐 [VIDEO CACHE] Playing directly from NETWORK: $url');

    // Возвращаем сетевой контроллер. Стриминг идет нативно плеером
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    // 🔥 ВКЛЮЧАЕМ ЗВУК ДЛЯ СЕТЕВОГО ВИДЕО
    await controller.setVolume(1.0);
    return controller;
  }

  /// 🔍 Проверка, есть ли видео в кеше
  Future<bool> isVideoCached(String url) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(url);
      final isCached = fileInfo != null && await fileInfo.file.exists();
      print('🔍 [VIDEO CACHE] Check cache for $url: ${isCached ? "✅ CACHED" : "❌ NOT CACHED"}');
      return isCached;
    } catch (e) {
      print('⚠️ [VIDEO CACHE] Error checking cache: $e');
      return false;
    }
  }

  /// 📁 Получение кешированного файла (если есть)
  Future<File?> getCachedFile(String url) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(url);
      if (fileInfo != null && await fileInfo.file.exists()) {
        return fileInfo.file;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🗑️ Полная очистка дискового кеша
  Future<void> clearCache() async {
    await _cacheManager.emptyCache();
    _downloadingMap.clear();
    _downloadStartTime.clear();
    print('🗑️ [VIDEO CACHE] Cleared successfully');
  }

  /// 🗑️ Удаление конкретного видео из кеша
  Future<void> removeVideoFromCache(String url) async {
    try {
      await _cacheManager.removeFile(url);
      print('🗑️ [VIDEO CACHE] Removed: $url');
    } catch (e) {
      print('❌ [VIDEO CACHE] Remove error: $e');
    }
  }

  /// 📊 Расчет размера кеша в байтах
  Future<int> getCacheSize() async {
    try {
      final dir = await getTemporaryDirectory();
      final cacheDir = Directory('${dir.path}/video_cache');
      if (await cacheDir.exists()) {
        int size = 0;
        await for (final FileSystemEntity file in cacheDir.list(recursive: true)) {
          if (file is File) {
            size += await file.length();
          }
        }
        return size;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// 📊 Получение размера кеша в читаемом формате
  Future<String> getCacheSizeFormatted() async {
    final size = await getCacheSize();
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// 📊 Количество кешированных медиафайлов (без служебных файлов БД)
  Future<int> getCachedFilesCount() async {
    try {
      final dir = await getTemporaryDirectory();
      final cacheDir = Directory('${dir.path}/video_cache');
      if (await cacheDir.exists()) {
        int count = 0;
        await for (final FileSystemEntity entity in cacheDir.list(recursive: true)) {
          if (entity is File && 
              !entity.path.endsWith('.db') && 
              !entity.path.endsWith('.json')) {
            count++;
          }
        }
        return count;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// 🔄 Статус загрузки
  bool isDownloading(String url) => _downloadingMap[url] == true;

  /// 🛑 Остановка всех трекингов загрузок
  void cancelAllDownloads() {
    _downloadingMap.clear();
    _downloadStartTime.clear();
    print('🛑 [VIDEO CACHE] All downloads cancelled');
  }

  /// 🗑️ Ручная принудительная очистка старого кеша (старше 7 дней)
  Future<void> cleanOldCache() async {
    try {
      final dir = await getTemporaryDirectory();
      final cacheDir = Directory('${dir.path}/video_cache');
      if (await cacheDir.exists()) {
        final now = DateTime.now();
        int deletedCount = 0;

        await for (final FileSystemEntity file in cacheDir.list(recursive: true)) {
          if (file is File && 
              !file.path.endsWith('.db') && 
              !file.path.endsWith('.json')) {
            final stat = await file.stat();
            final age = now.difference(stat.modified);
            if (age.inDays > 7) {
              await file.delete();
              deletedCount++;
            }
          }
        }
        print('🗑️ [VIDEO CACHE] Deleted $deletedCount old files');
      }
    } catch (e) {
      print('❌ [VIDEO CACHE] Clean old cache error: $e');
    }
  }
}