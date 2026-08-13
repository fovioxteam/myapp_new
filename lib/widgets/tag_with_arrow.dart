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
    const double arrowSize = 12.0; // Слегка увеличенная стрелочка

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
    final paint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Радиус скругления соразмерно увеличен
    const double radius = 16;

    // 1. Рисуем идеальный прямоугольник
    final RRect tagRect = RRect.fromLTRBR(
      0, 0, rectWidth, rectHeight,
      const Radius.circular(radius),
    );

    final path = Path();
    path.addRRect(tagRect);

    // 2. Добавляем аккуратную стрелочку
    final double centerX = rectWidth / 2;

    path.moveTo(centerX + arrowSize / 2, rectHeight);
    path.quadraticBezierTo(
      centerX,
      rectHeight + arrowSize,
      centerX - arrowSize / 2,
      rectHeight,
    );

    path.close();

    // 3. Отрисовываем единую фигуру без стыков и пикселей
    canvas.drawPath(path, paint);

    // 4. Текст чуть крупнее для баланса
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14.0, // 🔥 Увеличен с 13 до 14
          fontWeight: FontWeight.w600,
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