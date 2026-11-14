import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> migrateBadgesToPosts() async {
  final firestore = FirebaseFirestore.instance;
  final users = await firestore.collection('users').get();
  
  for (final user in users.docs) {
    final data = user.data();
    final badgeType = data['badgeType']?.toString() ?? '';
    final username = data['username']?.toString() ?? 'User';
    final avatarUrl = data['avatarUrl']?.toString() ?? '';

    final posts = await firestore.collection('posts').where('userId', isEqualTo: user.id).get();
    
    for (int i = 0; i < posts.docs.length; i += 400) {
      final batch = firestore.batch();
      final chunk = posts.docs.skip(i).take(400);

      for (final post in chunk) {
        batch.update(post.reference, {
          'userName': username,
          'userAvatar': avatarUrl,
          'userBadgeType': badgeType,
        });
      }
      await batch.commit();
      print('✅ ${user.id}: обновлено ${chunk.length} постов');
    }
  }
  print('🎉 Миграция завершена');
}