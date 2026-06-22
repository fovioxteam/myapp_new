import 'package:flutter/material.dart';

import '../models/post_tag.dart';

class PostTagsOverlay extends StatelessWidget {
  final List<PostTag> tags;
  final Function(PostTag) onTagTap;

  const PostTagsOverlay({
    super.key,
    required this.tags,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: tags.map((tag) {
            return Positioned(
              left: constraints.maxWidth * tag.x,
              top: constraints.maxHeight * tag.y,
              child: GestureDetector(
                onTap: () => onTagTap(tag),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.link,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}