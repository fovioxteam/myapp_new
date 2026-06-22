class LinkUtils {
  static String detectPlatform(String url) {
    final lower = url.toLowerCase();

    if (lower.contains('spotify')) {
      return 'spotify';
    }

    if (lower.contains('youtube') ||
        lower.contains('youtu.be')) {
      return 'youtube';
    }

    if (lower.contains('amazon')) {
      return 'amazon';
    }

    if (lower.contains('ozon')) {
      return 'ozon';
    }

    if (lower.contains('wildberries')) {
      return 'wildberries';
    }

    if (lower.contains('github')) {
      return 'github';
    }

    if (lower.contains('figma')) {
      return 'figma';
    }

    if (lower.contains('soundcloud')) {
      return 'soundcloud';
    }

    return 'link';
  }

  static bool isValidUrl(String value) {
    return Uri.tryParse(value)?.hasAbsolutePath ?? false;
  }
}