// lib/controllers/upload_controller.dart

import 'dart:io';
import 'package:get/get.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/media_service.dart';
import 'post_controller.dart';

class UploadController extends GetxController {
  static UploadController get to => Get.find();

  final MediaService _mediaService = MediaService();
  final PostController _postController = Get.find<PostController>();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final RxBool isCompressing = false.obs;
  final RxBool isUploading = false.obs;
  final RxDouble uploadProgress = 0.0.obs;
  final RxString errorMessage = ''.obs;
  
  late Future<Map<String, File?>> _compressedFuture;
  UploadTask? _currentUploadTask;

  /// 🔥 Начать сжатие сразу после выбора фото
  void startCompression(File file) {
    isCompressing.value = true;
    errorMessage.value = '';
    _compressedFuture = _mediaService.compressForUpload(file);
    _compressedFuture.then((_) {
      isCompressing.value = false;
    }).catchError((e) {
      isCompressing.value = false;
      errorMessage.value = 'Compression failed: ${e.toString()}';
      print('❌ Compression error: $e');
    });
  }

  /// 🔥 Получить результат сжатия
  Future<Map<String, File?>> getCompressedFiles() async {
    return await _compressedFuture;
  }

  /// 🔥 Загрузить в Firebase Storage (с прогрессом)
  Future<List<String>> uploadToStorage() async {
    isUploading.value = true;
    uploadProgress.value = 0.0;
    errorMessage.value = '';
    
    try {
      final compressed = await getCompressedFiles();
      final thumbnailFile = compressed['thumbnail'];
      final fullFile = compressed['full'];
      
      if (thumbnailFile == null || fullFile == null) {
        throw Exception('Compression failed');
      }
      
      final userId = _auth.currentUser!.uid;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final thumbnailPath = 'posts/$userId/thumb_$timestamp.jpg';
      final fullPath = 'posts/$userId/full_$timestamp.jpg';
      
      // Загружаем миниатюру
      final thumbnailRef = _storage.ref().child(thumbnailPath);
      final thumbnailTask = thumbnailRef.putFile(thumbnailFile);
      _currentUploadTask = thumbnailTask;
      
      thumbnailTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        uploadProgress.value = progress * 0.4; // 40% за миниатюру
      });
      
      final thumbnailSnapshot = await thumbnailTask;
      final thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();
      
      // Загружаем полное изображение
      final fullRef = _storage.ref().child(fullPath);
      final fullTask = fullRef.putFile(fullFile);
      _currentUploadTask = fullTask;
      
      fullTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        uploadProgress.value = 0.4 + (progress * 0.6); // 60% за полное
      });
      
      final fullSnapshot = await fullTask;
      final fullUrl = await fullSnapshot.ref.getDownloadURL();
      
      isUploading.value = false;
      uploadProgress.value = 1.0;
      _currentUploadTask = null;
      
      return [thumbnailUrl, fullUrl];
      
    } catch (e) {
      isUploading.value = false;
      errorMessage.value = 'Upload failed: ${e.toString()}';
      print('❌ Upload error: $e');
      rethrow;
    }
  }

  /// 🔥 Создать пост в Firestore
  Future<String?> createPost({
    required String caption,
    required List<String> imageUrls,
    required String thumbnailUrl,
    List<String>? hashtags,
  }) async {
    try {
      final userId = _auth.currentUser!.uid;
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userName = userDoc.data()?['username'] ?? 'User';
      final userAvatar = userDoc.data()?['avatarUrl'] ?? '';
      
      final postData = {
        'userId': userId,
        'userName': userName,
        'userAvatar': userAvatar,
        'imageUrls': imageUrls,
        'thumbnailUrl': thumbnailUrl,
        'caption': caption,
        'hashtags': hashtags ?? [],
        'likes': 0,
        'comments': 0,
        'saves': 0,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      final docRef = await _firestore.collection('posts').add(postData);
      final postId = docRef.id;
      
      // Добавляем в PostController
      _postController.addNewPost({
        'id': postId,
        ...postData,
      });
      
      return postId;
      
    } catch (e) {
      print('❌ Error creating post: $e');
      errorMessage.value = 'Failed to create post: ${e.toString()}';
      return null;
    }
  }

  /// 🔥 Отмена загрузки
  void cancelUpload() {
    _currentUploadTask?.cancel();
    isUploading.value = false;
    uploadProgress.value = 0.0;
    errorMessage.value = '';
  }

  /// 🔥 Геттеры для UI
  RxBool get isCompressingRx => isCompressing;
  RxBool get isUploadingRx => isUploading;
  RxDouble get progress => uploadProgress;
  RxString get error => errorMessage;
}