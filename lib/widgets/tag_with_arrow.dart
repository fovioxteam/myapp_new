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
    // 🔥 Чуть-чуть увеличиваем итоговые габариты всего тега
    final double adjustedWidth = width + 12;
    final double adjustedHeight = height + 4;
    const double arrowSize = 10.0; // Стрелка чуть меньше для остроты

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        size: Size(adjustedWidth, adjustedHeight + arrowSize),
        painter: _TagPainter(
          displayName: tag.displayName.isNotEmpty ? tag.displayName : 'Link',
          rectWidth: adjustedWidth,
          rectHeight: adjustedHeight,
          arrowSize: arrowSize,
        ),
      ),
    );
  }
}

class _TagPainter extends CustomPainter {
  final String displayName;
  final double rectWidth;
  final double rectHeight;
  final double arrowSize;

  _TagPainter({
    required this.displayName,
    required this.rectWidth,
    required this.rectHeight,
    required this.arrowSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 🔥 ЦВЕТ КАК В INSTAGRAM — ТЕМНО-СИНЕ-СЕРЫЙ
    final paint = Paint()
      ..color = const Color.fromARGB(255, 23, 28, 46) // 🔥 Instagram dark gray/blue
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 🔥 МЕНЬШЕ СКРУГЛЕНИЕ (Instagram использует ~8-10px)
    const double radius = 8.0;

    // 1. Рисуем прямоугольник с маленьким скруглением
    final RRect tagRect = RRect.fromLTRBR(
      0, 0, rectWidth, rectHeight,
      const Radius.circular(radius),
    );

    final path = Path();
    path.addRRect(tagRect);

    // 2. 🔥 ОСТРАЯ СТРЕЛКА (равнобедренный треугольник без скруглений)
    final double centerX = rectWidth / 2;
    final double arrowHalf = arrowSize / 2;

    path.moveTo(centerX - arrowHalf, rectHeight);
    path.lineTo(centerX, rectHeight + arrowSize);
    path.lineTo(centerX + arrowHalf, rectHeight);
    path.close();

    // 3. Отрисовываем единую фигуру
    canvas.drawPath(path, paint);

    // 4. Текст
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13.0,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout(maxWidth: rectWidth - 20);

    final textX = (rectWidth - textPainter.width) / 2;
    final textY = (rectHeight - textPainter.height) / 2;
    
    textPainter.paint(canvas, Offset(textX, textY));
  }

  @override
  bool shouldRepaint(covariant _TagPainter oldDelegate) {
    return oldDelegate.displayName != displayName ||
        oldDelegate.rectWidth != rectWidth ||
        oldDelegate.rectHeight != rectHeight;
  }
}