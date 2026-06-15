import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ImageCacheController {
  static final ImageCacheController _instance = ImageCacheController._internal();
  factory ImageCacheController() => _instance;
  ImageCacheController._internal();

  // Глобальный кэш изображений в памяти (как Uint8List)
  final Map<String, Uint8List> _imageCache = {};
  final Map<String, Widget> _widgetCache = {};

  // Загрузить изображение в память
  Future<Uint8List?> loadImage(String url) async {
    if (_imageCache.containsKey(url)) {
      return _imageCache[url];
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        _imageCache[url] = response.bodyBytes;
        return response.bodyBytes;
      }
    } catch (e) {
      print('❌ Failed to load image: $url - $e');
    }
    return null;
  }

  // Предзагрузить список изображений
  Future<void> preloadImages(List<String> urls) async {
    for (final url in urls) {
      if (!_imageCache.containsKey(url) && url.isNotEmpty) {
        await loadImage(url);
      }
    }
  }

  // Получить кэшированное изображение как виджет (СИНХРОННО - мгновенно!)
  Widget getCachedImage(String url, {VoidCallback? onTap, BoxFit fit = BoxFit.cover}) {
    // Проверяем кэш виджетов
    final widgetKey = 'widget_$url';
    if (_widgetCache.containsKey(widgetKey)) {
      return _widgetCache[widgetKey]!;
    }

    // Проверяем кэш байтов
    if (_imageCache.containsKey(url)) {
      final widget = GestureDetector(
        onTap: onTap,
        child: Image.memory(
          _imageCache[url]!,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        ),
      );
      _widgetCache[widgetKey] = widget;
      return widget;
    }

    // Если нет в кэше - показываем плейсхолдер и загружаем
    final widget = FutureBuilder<Uint8List?>(
      future: loadImage(url),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return GestureDetector(
            onTap: onTap,
            child: Image.memory(
              snapshot.data!,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            ),
          );
        }
        return Container(color: Colors.grey[300]);
      },
    );
    
    _widgetCache[widgetKey] = widget;
    return widget;
  }

  // Очистить кэш
  void clearCache() {
    _imageCache.clear();
    _widgetCache.clear();
  }

  // Очистить кэш по URL
  void clearCacheByUrl(String url) {
    _imageCache.remove(url);
    _widgetCache.remove('widget_$url');
  }
}