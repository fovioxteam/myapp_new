import 'package:flutter/material.dart';
import '../models/post_tag.dart';
import 'tag_with_arrow.dart';

class AnimatedTag extends StatefulWidget {
  final PostTag tag;
  final VoidCallback onTap;
  final int index;
  final bool isVisible;

  const AnimatedTag({
    super.key,
    required this.tag,
    required this.onTap,
    required this.index,
    required this.isVisible,
  });

  @override
  State<AnimatedTag> createState() => _AnimatedTagState();
}

class _AnimatedTagState extends State<AnimatedTag>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    // 👇 ПЕРВОНАЧАЛЬНОЕ СОСТОЯНИЕ
    if (widget.isVisible) {
      _controller.value = 1.0;
    } else {
      _controller.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedTag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textWidth = widget.tag.displayName.length * 7.5 + 12;
    final width = textWidth + 10;
    final height = 22.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = _scaleAnimation.value;
        final opacity = _opacityAnimation.value;
        
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: SizedBox(
              width: width,
              height: height + 7,
              child: TagWithArrow(
                tag: widget.tag,
                width: width,
                height: height,
                onTap: widget.onTap,
              ),
            ),
          ),
        );
      },
    );
  }
}