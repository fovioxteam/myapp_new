// lib/services/status_bar_service.dart

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class StatusBarService {
  static const StatusBarService _instance = StatusBarService._internal();
  factory StatusBarService() => _instance;
  const StatusBarService._internal();

  // 🔥 БЕЛЫЕ ИКОНКИ (для Feed Screen)
  void setWhiteStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // БЕЛЫЕ иконки
        statusBarBrightness: Brightness.dark, // для iOS
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  // 🔥 ЧЕРНЫЕ ИКОНКИ (для всех остальных)
  void setDarkStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // ЧЕРНЫЕ иконки
        statusBarBrightness: Brightness.light, // для iOS
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // 🔥 АВТОМАТИЧЕСКИ ПО ТЕМЕ (если нужно)
  void setStatusBarForTheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      setWhiteStatusBar();
    } else {
      setDarkStatusBar();
    }
  }
}