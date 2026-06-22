class PostTag {
  final double x;
  final double y;
  final String url;
  final String platform;

  const PostTag({
    required this.x,
    required this.y,
    required this.url,
    required this.platform,
  });

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'url': url,
      'platform': platform,
    };
  }

  factory PostTag.fromJson(Map<String, dynamic> json) {
    return PostTag(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      url: json['url'] ?? '',
      platform: json['platform'] ?? 'link',
    );
  }
}