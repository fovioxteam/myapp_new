// lib/services/image_cache_service.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  // Кэш изображений в памяти
  final Map<String, Uint8List> _cache = {};
  final Map<String, Widget> _widgetCache = {};
  
  // Максимальный размер кэша (50 МБ)
  static const int _maxCacheSize = 50 * 1024 * 1024;
  int _currentCacheSize = 0;

  // Загрузить изображение в память
  Future<Uint8List?> loadImage(String url) async {
    if (_cache.containsKey(url)) {
      return _cache[url];
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        _cache[url] = bytes;
        _currentCacheSize += bytes.length;
        
        // Если превысили лимит - очищаем кэш
        if (_currentCacheSize > _maxCacheSize) {
          _clearCache();
        }
        
        return bytes;
      }
    } catch (e) {
      print('❌ Failed to load image: $url - $e');
    }
    return null;
  }

  // Получить кэшированное изображение как виджет
  Widget getCachedImage(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    final widgetKey = 'widget_$url';
    
    if (_widgetCache.containsKey(widgetKey)) {
      return _widgetCache[widgetKey]!;
    }

    if (_cache.containsKey(url)) {
      final widget = Image.memory(
        _cache[url]!,
        fit: fit,
        width: width,
        height: height,
        gaplessPlayback: true,
      );
      _widgetCache[widgetKey] = widget;
      return widget;
    }

    // Если нет в кэше - загружаем асинхронно
    final widget = FutureBuilder<Uint8List?>(
      future: loadImage(url),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: fit,
            width: width,
            height: height,
            gaplessPlayback: true,
          );
        }
        return Container(color: Colors.grey[300]);
      },
    );
    
    _widgetCache[widgetKey] = widget;
    return widget;
  }

  // Предзагрузить изображения
  Future<void> preloadImages(List<String> urls) async {
    for (final url in urls) {
      if (!_cache.containsKey(url) && url.isNotEmpty) {
        await loadImage(url);
      }
    }
  }

  void _clearCache() {
    _cache.clear();
    _widgetCache.clear();
    _currentCacheSize = 0;
  }

  void clearCache() {
    _clearCache();
  }
}