// lib/widgets/profile_posts_grid.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/post_controller.dart';
import '../extensions/safe_extensions.dart';

class ProfilePostsGrid extends StatelessWidget {
  final String userId;
  final PostController postController;
  final Function(Map<String, dynamic>) onPostTap;

  const ProfilePostsGrid({
    super.key,
    required this.userId,
    required this.postController,
    required this.onPostTap,
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
      final firstUrl = imageUrls[0]?.toString();
      if (firstUrl != null && firstUrl.isNotEmpty) {
        return firstUrl;
      }
    }
    
    final images = post["images"];
    if (images is List && images.isNotEmpty) {
      final firstImage = images[0]?.toString();
      if (firstImage != null && firstImage.isNotEmpty) {
        return firstImage;
      }
    }
    
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 РЕАКТИВНОЕ ОБНОВЛЕНИЕ - БЕЗ setState!
    return Obx(() {
      final posts = postController.userPosts[userId] ?? [];
      
      print('📸 [ProfilePostsGrid] Building grid with ${posts.length} posts');
      
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
                  style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  "Share your first creative work!",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
      
      return GridView.builder(
        padding: const EdgeInsets.all(1),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
          childAspectRatio: 0.8,
        ),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final imageUrl = _getThumbnailUrl(post);
          
          return GestureDetector(
            onTap: () => onPostTap(post),
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.grey[100],
              child: imageUrl.isNotEmpty && imageUrl.startsWith('http')
                  ? CachedNetworkImage(
                      key: ValueKey('${post['id']}_$imageUrl'),
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 300,
                      memCacheHeight: 300,
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
            ),
          );
        },
      );
    });
  }
}