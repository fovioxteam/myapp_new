class FormatUtils {
  static String formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      // 1,000 - 999,999: 1,234 → 1.2k
      final double value = count / 1000;
      return _formatDecimal(value, 'k');
    } else if (count < 1000000000) {
      // 1,000,000 - 999,999,999: 1,234,567 → 1.2m
      final double value = count / 1000000;
      return _formatDecimal(value, 'm');
    } else {
      // 1,000,000,000+: 1,234,567,890 → 1.2b
      final double value = count / 1000000000;
      return _formatDecimal(value, 'b');
    }
  }

  static String _formatDecimal(double value, String suffix) {
    if (value >= 100) {
      // Для значений ≥ 100: 123.4k → 123k (без десятичных)
      return '${value.toInt()}$suffix';
    } else if (value >= 10) {
      // Для значений ≥ 10: 12.3k → 12k (без десятичных)
      return '${value.toInt()}$suffix';
    } else {
      // Для значений < 10: 1.23k → 1.2k (одна десятичная)
      return '${value.toStringAsFixed(1)}$suffix';
    }
  }

  // Дополнительный метод для форматирования с запятыми
  static String formatWithCommas(int count) {
    final String numberStr = count.toString();
    final StringBuffer result = StringBuffer();
    final int length = numberStr.length;

    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        result.write(',');
      }
      result.write(numberStr[i]);
    }

    return result.toString();
  }
}