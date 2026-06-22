// lib/widgets/profile_posts_grid.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../controllers/post_controller.dart';

class ProfilePostsGrid extends StatelessWidget {
  final String userId;
  final PostController postController;
  final Function(String) onPostTap;
  final List<Map<String, dynamic>>? customPosts;

  const ProfilePostsGrid({
    super.key,
    required this.userId,
    required this.postController,
    required this.onPostTap,
    this.customPosts,
  });

  String _getThumbnailUrl(Map<String, dynamic> post) {
    if (post["thumbnailUrl"] != null && post["thumbnailUrl"].toString().isNotEmpty) {
      return post["thumbnailUrl"].toString();
    }
    if (post["imageUrl"] != null && post["imageUrl"].toString().isNotEmpty) {
      return post["imageUrl"].toString();
    }
    if (post["url"] != null && post["url"].toString().isNotEmpty) {
      return post["url"].toString();
    }

    final imageUrls = post["imageUrls"];
    if (imageUrls is List && imageUrls.isNotEmpty) {
      final first = imageUrls.first?.toString() ?? '';
      if (first.isNotEmpty) return first;
    }

    final images = post["images"];
    if (images is List && images.isNotEmpty) {
      final first = images.first?.toString() ?? '';
      if (first.isNotEmpty) return first;
    }

    if (post["post"] is Map<String, dynamic>) {
      return _getThumbnailUrl(post["post"] as Map<String, dynamic>);
    }
    if (post["postData"] is Map<String, dynamic>) {
      return _getThumbnailUrl(post["postData"] as Map<String, dynamic>);
    }
    if (post["item"] is Map<String, dynamic>) {
      return _getThumbnailUrl(post["item"] as Map<String, dynamic>);
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final posts = customPosts ?? (postController.userPosts[userId] ?? []);

    if (posts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "No posts yet",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(
        left: 1,
        right: 1,
        top: 1,
        bottom: 80,
      ),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 0.75,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final imageUrl = _getThumbnailUrl(post);
        final postId = post['id']?.toString() ?? '';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onPostTap(postId),
          child: Container(
            color: Colors.grey[200],
            child: imageUrl.isNotEmpty && imageUrl.startsWith('http')
                ? CachedNetworkImage(
                    key: ValueKey('grid_${post['id']}_$imageUrl'),
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                    memCacheWidth: 400,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                    ),
                    errorWidget: (context, url, error) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
          ),
        );
      },
    );
  }
}