// lib/extensions/safe_extensions.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../extensions/safe_extensions.dart';

/// Безопасные расширения для списков
extension SafeListExtension<T> on List<T> {
  /// Безопасный доступ к первому элементу (возвращает null если список пуст)
  T? get safeFirst => isEmpty ? null : first;
  
  /// Безопасный доступ по индексу
  T? elementAtSafe(int index) {
    if (index >= 0 && index < length) return this[index];
    return null;
  }
  
  /// Безопасный firstWhere (возвращает null если элемент не найден)
  T? firstWhereSafe(bool Function(T) test) {
    for (var item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}

/// Безопасные расширения для множеств (Set)
extension SafeSetExtension<T> on Set<T> {
  /// Безопасный доступ к первому элементу
  T? get safeFirst => isEmpty ? null : first;
}

/// Безопасные расширения для Iterable
extension SafeIterableExtension<T> on Iterable<T> {
  /// Безопасный доступ к первому элементу
  T? get safeFirst => isEmpty ? null : first;
}

/// Безопасные расширения для QuerySnapshot
extension SafeQuerySnapshotExtension on QuerySnapshot {
  /// Безопасный доступ к первому документу
  QueryDocumentSnapshot? get safeFirst => docs.isEmpty ? null : docs.first;
}

/// Безопасные расширения для DocumentSnapshot
extension SafeDocumentSnapshotExtension on DocumentSnapshot {
  /// Безопасное получение данных
  Map<String, dynamic>? get safeData {
    final data = this.data();
    if (data is Map<String, dynamic>) return data;
    return null;
  }
}