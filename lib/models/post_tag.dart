class PostTag {
  final String id;
  double x;
  double y;
  final String url;
  final String platform;
  final String displayName;

  PostTag({
    required this.id,
    required this.x,
    required this.y,
    required this.url,
    required this.platform,
    this.displayName = '',
  });

  void updatePosition(double newX, double newY) {
    x = newX.clamp(0.0, 1.0);
    y = newY.clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'url': url,
      'platform': platform,
      'displayName': displayName,
    };
  }

  factory PostTag.fromJson(Map<String, dynamic> json) {
    return PostTag(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      url: json['url'] ?? '',
      platform: json['platform'] ?? 'link',
      displayName: json['displayName'] ?? '',
    );
  }
}