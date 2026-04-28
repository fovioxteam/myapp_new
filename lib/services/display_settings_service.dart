// lib/services/display_settings_service.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../extensions/safe_extensions.dart';

class DisplaySettingsService {
  static const String _keyFitMode = 'post_fit_mode';
  static const String _keyZoom = 'post_zoom';
  static const String _keyPanX = 'post_pan_x';
  static const String _keyPanY = 'post_pan_y';
  static const String _keyScale = 'post_scale';
  
  static final DisplaySettingsService _instance = DisplaySettingsService._internal();
  factory DisplaySettingsService() => _instance;
  DisplaySettingsService._internal();
  
  // Сохраняем режим отображения (true = cover, false = contain)
  Future<void> saveFitMode(bool isCover) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFitMode, isCover);
    print('💾 Saved fit mode: ${isCover ? "Full" : "Auto"}');
  }
  
  // Загружаем режим отображения
  Future<bool> loadFitMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isCover = prefs.getBool(_keyFitMode) ?? true;
    print('📂 Loaded fit mode: ${isCover ? "Full" : "Auto"}');
    return isCover;
  }
  
  // ========== 🔥 ИСПРАВЛЕННЫЙ МЕТОД saveTransform ==========
  // Сохраняем трансформацию (зум и позиция)
  Future<void> saveTransform(Matrix4 transform) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = transform.storage;
    
    // ✅ ИСПРАВЛЕНО: безопасная проверка длины массива
    if (storage.length > 13) {
      await prefs.setDouble(_keyZoom, storage[0]); // scale x
      await prefs.setDouble(_keyPanX, storage[12]); // translate x
      await prefs.setDouble(_keyPanY, storage[13]); // translate y
      await prefs.setDouble(_keyScale, storage[5]); // scale y
      print('💾 Saved transform: scale=${storage[0]}, pan=(${storage[12]},${storage[13]})');
    } else {
      print('⚠️ Storage array length ${storage.length} is less than expected (min 14)');
    }
  }
  
  // Загружаем трансформацию
  Future<Matrix4> loadTransform() async {
    final prefs = await SharedPreferences.getInstance();
    final zoom = prefs.getDouble(_keyZoom);
    final panX = prefs.getDouble(_keyPanX);
    final panY = prefs.getDouble(_keyPanY);
    final scale = prefs.getDouble(_keyScale);
    
    if (zoom != null && panX != null && panY != null && scale != null) {
      print('📂 Loaded transform: scale=$zoom, pan=($panX,$panY)');
      return Matrix4(
        zoom, 0, 0, panX,
        0, scale, 0, panY,
        0, 0, 1, 0,
        0, 0, 0, 1,
      );
    }
    print('📂 No saved transform, using identity');
    return Matrix4.identity();
  }
  
  // Сброс настроек
  Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFitMode);
    await prefs.remove(_keyZoom);
    await prefs.remove(_keyPanX);
    await prefs.remove(_keyPanY);
    await prefs.remove(_keyScale);
    print('🗑️ Display settings reset');
  }
}