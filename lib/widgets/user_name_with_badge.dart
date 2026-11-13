import 'dart:math' as math;
import 'package:flutter/material.dart';

class UserNameWithBadge extends StatelessWidget {
  final String name;
  final String? badgeType; // 'gold', 'blue', или null
  final TextStyle? style;
  final double iconSize;
  final MainAxisAlignment alignment;
  final Widget? customBadge; // ✅ НОВОЕ: кастомная галочка

  const UserNameWithBadge({
    super.key,
    required this.name,
    this.badgeType,
    this.style,
    this.iconSize = 14,
    this.alignment = MainAxisAlignment.start,
    this.customBadge,
  });

  @override
  Widget build(BuildContext context) {
    final badgeConfig = _getBadgeConfig(badgeType);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            name,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // ✅ Приоритет: customBadge > badgeConfig
        if (customBadge != null) ...[
          const SizedBox(width: 2),
          customBadge!,
        ] else if (badgeConfig != null) ...[
          const SizedBox(width: 2),
          Tooltip(
            message: badgeConfig.tooltip,
            triggerMode: TooltipTriggerMode.tap,
            preferBelow: false,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            child: _InstagramVerifiedBadge(
              size: iconSize,
              color: badgeConfig.color,
            ),
          ),
        ],
      ],
    );
  }

  _BadgeConfig? _getBadgeConfig(String? type) {
    switch (type) {
      case 'gold':
        return const _BadgeConfig(
          color: Color(0xFFFFB800),
          tooltip: 'Founding Partner • Официальный магазин',
        );
      case 'blue':
        return const _BadgeConfig(
          color: Color(0xFF0095F6),
          tooltip: 'Foviox PRO • Подтверждённый аккаунт',
        );
      default:
        return null;
    }
  }
}

class _BadgeConfig {
  final Color color;
  final String tooltip;

  const _BadgeConfig({
    required this.color,
    required this.tooltip,
  });
}

/// Векторный виджет галочки, точно повторяющий форму 8-лепестковой розетки Instagram
class _InstagramVerifiedBadge extends StatelessWidget {
  final double size;
  final Color color;

  const _InstagramVerifiedBadge({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _InstagramBadgePainter(color: color),
      ),
    );
  }
}

class _InstagramBadgePainter extends CustomPainter {
  final Color color;

  _InstagramBadgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final badgePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();
    const int lobes = 8;
    const int steps = 160;
    final double baseRadius = w * 0.435;
    final double waveAmplitude = w * 0.055;

    for (int i = 0; i <= steps; i++) {
      final double theta = (i / steps) * 2 * math.pi;
      final double r = baseRadius + waveAmplitude * math.cos(lobes * theta);
      final double x = center.dx + r * math.cos(theta);
      final double y = center.dy + r * math.sin(theta);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, badgePaint);

    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.115
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final checkPath = Path()
      ..moveTo(w * 0.31, h * 0.51)
      ..lineTo(w * 0.44, h * 0.64)
      ..lineTo(w * 0.70, h * 0.37);

    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _InstagramBadgePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}