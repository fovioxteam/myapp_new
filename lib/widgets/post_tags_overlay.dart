import 'package:flutter/material.dart';
import '../models/post_tag.dart';
import 'animated_tag.dart';

class PostTagsOverlay extends StatefulWidget {
  final List<PostTag> tags;
  final Function(PostTag) onTagTap;
  final bool isVisible;
  final Function(PostTag, double, double)? onTagMoved;
  final int? carouselIndex;

  const PostTagsOverlay({
    super.key,
    required this.tags,
    required this.onTagTap,
    required this.isVisible,
    this.onTagMoved,
    this.carouselIndex,
  });

  @override
  State<PostTagsOverlay> createState() => _PostTagsOverlayState();
}

class _PostTagsOverlayState extends State<PostTagsOverlay> {
  bool _isDragging = false;
  int? _draggingIndex;

  @override
  Widget build(BuildContext context) {
    // 👇 УБИРАЕМ ПРОВЕРКУ !widget.isVisible — ВСЕГДА РЕНДЕРИМ
    if (widget.tags.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: widget.tags.asMap().entries.map((entry) {
            final index = entry.key;
            final tag = entry.value;
            
            return Positioned(
              left: constraints.maxWidth * tag.x - 14,
              top: constraints.maxHeight * tag.y - 14,
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _isDragging = true;
                    _draggingIndex = index;
                  });
                },
                onPanUpdate: (details) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final localOffset = box.globalToLocal(details.globalPosition);
                  
                  final newX = (localOffset.dx / constraints.maxWidth).clamp(0.0, 1.0);
                  final newY = (localOffset.dy / constraints.maxHeight).clamp(0.0, 1.0);
                  
                  setState(() {
                    tag.updatePosition(newX, newY);
                  });
                  
                  if (widget.onTagMoved != null) {
                    widget.onTagMoved!(tag, newX, newY);
                  }
                },
                onPanEnd: (details) {
                  setState(() {
                    _isDragging = false;
                    _draggingIndex = null;
                  });
                },
                child: AnimatedTag(
                  tag: tag,
                  index: index,
                  isVisible: widget.isVisible,
                  onTap: () => widget.onTagTap(tag),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}