import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

abstract class BaseProfileScreen extends StatefulWidget {
  final String userId;
  final bool isMyProfile;

  const BaseProfileScreen({
    super.key,
    required this.userId,
    required this.isMyProfile,
  });

  @override
  State<BaseProfileScreen> createState(); // <-- ИСПРАВЛЕНА ЭТА СТРОКА
}

abstract class BaseProfileScreenState<T extends BaseProfileScreen>
    extends State<T> {

  Widget buildAvatar(String avatarUrl, double size) {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          color: Colors.grey.shade300,
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          color: Colors.grey.shade300,
          child: Icon(
            Icons.person,
            size: size * 0.5,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget buildStatItem(int number, String label, {
    VoidCallback? onTap,
  }) {
    final child = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          number.toString(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );

    if (onTap == null) return child;

    return GestureDetector(
      onTap: onTap,
      child: child,
    );
  }

  Widget buildPostsGrid(List<Map<String, dynamic>> posts) {
    if (posts.isEmpty) {
      return const Center(
        child: Text(
          "No posts yet",
          style: TextStyle(color: Colors.black54, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemBuilder: (context, index) {
        return CachedNetworkImage(
          imageUrl: posts[index]["imageUrl"] ?? "",
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.grey.shade300),
          errorWidget: (context, url, error) => Container(color: Colors.grey.shade300),       
        );
      },
    );
  }
}