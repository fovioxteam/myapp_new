import 'package:flutter/material.dart';
import '../models/post_tag.dart';

class TagWithArrow extends StatelessWidget {
  final PostTag tag;
  final VoidCallback onTap;
  final double width;
  final double height;

  const TagWithArrow({
    super.key,
    required this.tag,
    required this.onTap,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        size: Size(width + 16, height + 1),
        painter: _TagPainter(
          displayName: tag.displayName.isNotEmpty ? tag.displayName : 'Link',
          width: width + 16,
          height: height + 1,
        ),
      ),
    );
  }
}

class _TagPainter extends CustomPainter {
  final String displayName;
  final double width;
  final double height;

  _TagPainter({
    required this.displayName,
    required this.width,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.fill;

    final double arrowSize = 11;
    // 👇 УВЕЛИЧИЛ СКРУГЛЕНИЕ (было 10, стало 15)
    final double radius = 15;

    final path = Path();

    // ---- 1. НАЧИНАЕМ С ЛЕВОГО ВЕРХНЕГО УГЛА ----
    path.moveTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.lineTo(width - radius, 0);
    path.quadraticBezierTo(width, 0, width, radius);
    path.lineTo(width, height - radius);
    path.quadraticBezierTo(width, height, width - radius, height);

    // ---- 2. СТРЕЛКА ВНИЗ ----
    final double centerX = width / 2;
    path.lineTo(centerX + arrowSize / 2, height);
    path.quadraticBezierTo(
      centerX,
      height + arrowSize,
      centerX - arrowSize / 2,
      height,
    );
    path.lineTo(radius, height);

    // ---- 3. ЗАКРЫВАЕМ ФИГУРУ СЛЕВА ----
    path.quadraticBezierTo(0, height, 0, height - radius);
    path.lineTo(0, radius);
    path.close();

    canvas.drawPath(path, paint);

    // ---- 4. ТЕКСТ ----
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: width - 20);

    final textX = (width - textPainter.width) / 2;
    final textY = (height - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(textX, textY));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}