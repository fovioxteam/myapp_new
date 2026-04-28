// lib/screens/post_edit_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:photo_manager/photo_manager.dart';

import '../controllers/post_controller.dart';

class PostEditScreen extends StatefulWidget {
  final List<dynamic> images; // Может содержать AssetEntity, File, String

  const PostEditScreen({
    super.key,
    required this.images,
  });

  @override
  State<PostEditScreen> createState() => _PostEditScreenState();
}

class _PostEditScreenState extends State<PostEditScreen> {
  final TextEditingController _captionController = TextEditingController();
  final PageController _pageController = PageController();
  final PostController _postController = Get.find<PostController>();
  int _currentPage = 0;
  bool _isUploading = false;
  
  // Данные пользователя
  String _userName = '';
  String _userAvatar = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.displayName ?? 'username';
        _userAvatar = user.photoURL ?? '';
      });
    }
  }

  Future<File?> _getFileFromImage(dynamic image) async {
    if (image is AssetEntity) {
      return await image.file;
    } else if (image is File) {
      return image;
    }
    return null;
  }

  bool _isUrl(dynamic image) {
    return image is String && (image.startsWith('http') || image.startsWith('https'));
  }

  Future<void> _publishPost() async {
    if (_isUploading) return;
    
    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // ПОЛУЧАЕМ АКТУАЛЬНЫЕ ДАННЫЕ ПОЛЬЗОВАТЕЛЯ ИЗ FIRESTORE
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userData = userDoc.data() ?? {};
      final userName = userData['username'] ?? _userName;
      final userAvatar = userData['avatarUrl'] ?? _userAvatar;

      List<String> imageUrls = [];

      for (int i = 0; i < widget.images.length; i++) {
        final image = widget.images[i];
        
        if (_isUrl(image)) {
          imageUrls.add(image as String);
          continue;
        }

        final file = await _getFileFromImage(image);
        if (file == null) continue;

        final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = FirebaseStorage.instance.ref().child('posts/$fileName');
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      if (imageUrls.isEmpty) throw Exception('No images to upload');

      // СОЗДАЕМ ПОСТ В FIRESTORE
      final postData = {
        'userId': user.uid,
        'userName': userName,
        'userAvatar': userAvatar,
        'images': imageUrls,
        'imageUrls': imageUrls,
        'caption': _captionController.text,
        'likes': 0,
        'comments': 0,
        'saves': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'fitMode': 'cover',
        'status': 'testing',
      };

      final docRef = await FirebaseFirestore.instance
          .collection('posts')
          .add(postData);
      
      await docRef.update({'id': docRef.id});

      // ДОБАВЛЯЕМ ПОСТ В POSTCONTROLLER
      final newPost = {
        'id': docRef.id,
        ...postData,
        'createdAt': DateTime.now(),
      };
      _postController.addPostsToStorage([newPost], markAsInFeed: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post published successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Возвращаемся на главный экран (feed)
        Navigator.popUntil(context, (route) => route.isFirst);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _buildImage(dynamic image) {
    if (_isUrl(image)) {
      return Image.network(
        image as String,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[900],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
            ),
          );
        },
      );
    } else {
      return FutureBuilder<File?>(
        future: _getFileFromImage(image),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              color: Colors.grey[900],
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }
          return Image.file(
            snapshot.data!,
            fit: BoxFit.contain,
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Post',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _publishPost,
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : const Text(
                    'Share',
                    style: TextStyle(color: Colors.blue, fontSize: 16),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Карусель изображений
          Expanded(
            flex: 3,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                return Container(
                  color: Colors.black,
                  child: Center(
                    child: _buildImage(widget.images[index]),
                  ),
                );
              },
            ),
          ),

          // Индикаторы карусели
          if (widget.images.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index ? Colors.blue : Colors.grey,
                    ),
                  );
                }),
              ),
            ),

          // Информация о пользователе и поле для описания
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: const Border(
                top: BorderSide(color: Colors.grey, width: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: _userAvatar.isNotEmpty
                      ? NetworkImage(_userAvatar)
                      : null,
                  backgroundColor: Colors.grey[800],
                  child: _userAvatar.isEmpty
                      ? const Icon(Icons.person, color: Colors.grey, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _captionController,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Write a caption...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}