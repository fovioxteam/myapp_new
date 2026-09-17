import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NavBarController extends GetxController {
  /// 1.0 — меню полное, 0.0 — полностью сжато/скрыто
  final RxDouble visibility = 1.0.obs;

  double _lastOffset = 0;

  /// Вызывается из NotificationListener<ScrollNotification>
  void handleScroll(ScrollNotification notification) {
    // Реагируем только на вертикальный скролл
    if (notification.metrics.axis != Axis.vertical) return;

    final offset = notification.metrics.pixels;
    final diff = offset - _lastOffset;

    // Скролл вниз → сжимаем (но только если проскроллили >50px)
    if (diff > 2 && offset > 50) {
      visibility.value = 0.0;
    }
    // Скролл вверх → раскрываем
    else if (diff < -2) {
      visibility.value = 1.0;
    }

    _lastOffset = offset;
  }

  /// Сбросить в исходное положение (например, при смене таба)
  void reset() {
    visibility.value = 1.0;
    _lastOffset = 0;
  }
}