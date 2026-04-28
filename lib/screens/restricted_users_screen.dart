import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../extensions/safe_extensions.dart';

class RestrictedUsersScreen extends StatefulWidget {
  const RestrictedUsersScreen({super.key});

  @override
  State<RestrictedUsersScreen> createState() => _RestrictedUsersScreenState();
}

class _RestrictedUsersScreenState extends State<RestrictedUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> _restrictedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRestrictedUsers();
  }

  // ========== 🔥 ИСПРАВЛЕННЫЙ МЕТОД ==========
  Future<void> _loadRestrictedUsers() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final restrictedQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('restrictedUsers')
          .get();

      final restrictedIds = restrictedQuery.docs.map((doc) => doc.id).toList();
      
      if (restrictedIds.isNotEmpty) {
        final usersQuery = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: restrictedIds)
            .get();

        setState(() {
          _restrictedUsers = usersQuery.docs.map((doc) {
            final data = doc.data();
            // ✅ ИСПРАВЛЕНО: безопасное получение restrictedDoc через firstWhereOrNull
            final restrictedDoc = restrictedQuery.docs.firstWhereOrNull(
              (restrictedDoc) => restrictedDoc.id == doc.id
            );
            
            // ✅ Безопасное получение данных
            final restrictedData = restrictedDoc?.data();
            final restrictedAt = restrictedData != null && restrictedData['restrictedAt'] != null 
                ? restrictedData['restrictedAt'] 
                : null;
            
            return {
              'id': doc.id,
              'username': data['username'] ?? 'User',
              'avatarUrl': data['avatarUrl'] ?? '',
              'restrictedAt': restrictedAt,
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _restrictedUsers = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading restricted users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unrestrictUser(String userId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('restrictedUsers')
          .doc(userId)
          .delete();

      setState(() {
        _restrictedUsers.removeWhere((user) => user['id'] == userId);
      });

      Get.snackbar(
        'Success',
        'Restrictions removed',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error unrestricting user: $e');
      Get.snackbar(
        'Error',
        'Failed to remove restrictions',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildRestrictedUserItem(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: (user['avatarUrl'] != null && user['avatarUrl'].toString().isNotEmpty)
              ? CachedNetworkImageProvider(user['avatarUrl'].toString())
              : const AssetImage('assets/default_avatar.png') as ImageProvider,
        ),
        title: Text(
          user['username'] ?? 'User',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Restricted',
              style: TextStyle(fontSize: 12),
            ),
            if (user['restrictedAt'] != null)
              Text(
                'Since ${_formatDate((user['restrictedAt'] as Timestamp).toDate())}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.info_outline, color: Colors.grey[600]),
              onPressed: () => _showRestrictionInfo(),
              tooltip: 'What does "restricted user" mean?',
            ),
            ElevatedButton(
              onPressed: () => _showUnrestrictDialog(user['id'], user['username'] ?? 'User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestrictionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restricted User'),
        content: const Text(
          'Restricted users cannot see when you are online, '
          'will not see your new posts in their feed, and cannot see '
          'if you have read their messages.\n\n'
          'They will not know that you have restricted them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showUnrestrictDialog(String userId, String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove restrictions?'),
        content: Text('Are you sure you want to remove restrictions from $username?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unrestrictUser(userId);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Restricted Users',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _restrictedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No restricted users',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Restrict users to hide your activity from them',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: const Text(
                        'Restricted users will not know that you have restricted them. '
                        'They will not see your activity or new posts.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _restrictedUsers.length,
                        itemBuilder: (context, index) {
                          return _buildRestrictedUserItem(_restrictedUsers[index]);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}