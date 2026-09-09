// lib/screens/post_caption_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../controllers/profile_controller.dart';
import '../controllers/post_controller.dart';
import '../extensions/safe_extensions.dart';
import '../models/post_tag.dart';
import '../models/media_types.dart';
import '../services/recommendation_service.dart';
import '../services/r2_service.dart';
import '../utils/image_compressor.dart';
import '../utils/video_compressor.dart';

class PostCaptionScreen extends StatefulWidget {
  final List<File> selectedFiles;
  final List<String>? fitModes;
  final List<PostTag> tags;
  final MediaUploadType mediaType;

  const PostCaptionScreen({
    super.key,
    required this.selectedFiles,
    this.fitModes,
    this.tags = const [],
    this.mediaType = MediaUploadType.image,
  });

  @override
  State<PostCaptionScreen> createState() => _PostCaptionScreenState();
}

class _PostCaptionScreenState extends State<PostCaptionScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final PostController _postController = Get.find<PostController>();
  final R2Service _r2Service = R2Service();
  
  final TextEditingController _captionController = TextEditingController();
  final int _maxCaptionLength = 2200;
  
  final List<String> _selectedHashtags = [];
  final List<String> _suggestedHashtags = [
    'art', 'photography', 'nature', 'travel', 'food', 
    'fashion', 'fitness', 'music', 'love', 'happy',
    'instagood', 'beautiful', 'style', 'life', 'fun',
    'design', 'creative', 'inspiration', 'artwork', 'digitalart'
  ];

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  File? _cachedThumbnail;
  bool _thumbnailLoading = false;

  bool get _isVideo => widget.mediaType == MediaUploadType.video;

  @override
  void initState() {
    super.initState();
    _captionController.addListener(_updateRemainingChars);
    print('🔥 [CAPTION] INITIALIZED');
    print('🔥 [CAPTION] Media type: ${widget.mediaType}');
    print('🔥 [CAPTION] Total files: ${widget.selectedFiles.length}');
    print('🔥 [CAPTION] Tags count: ${widget.tags.length}');
    
    if (_isVideo) {
      _preloadThumbnail();
    }
  }

  @override
  void dispose() {
    _captionController.removeListener(_updateRemainingChars);
    _captionController.dispose();
    
    if (_cachedThumbnail != null && _cachedThumbnail!.existsSync()) {
      _cachedThumbnail!.delete().catchError((e) => print('Thumbnail cleanup error: $e'));
    }
    _cachedThumbnail = null;
    
    super.dispose();
  }

  void _preloadThumbnail() async {
    if (_cachedThumbnail != null || _thumbnailLoading) return;
    
    _thumbnailLoading = true;
    try {
      final videoFile = widget.selectedFiles.first;
      // 🔥 ИСПРАВЛЕНО: передаём File, а не String
      final thumbnail = await VideoCompressor.generateThumbnail(videoFile);
      
      if (mounted) {
        setState(() {
          _cachedThumbnail = thumbnail;
          _thumbnailLoading = false;
        });
      }
    } catch (e) {
      print('❌ [THUMBNAIL] Preload error: $e');
      if (mounted) {
        setState(() {
          _thumbnailLoading = false;
        });
      }
    }
  }

  void _updateRemainingChars() {
    if (mounted) setState(() {});
  }

  int get _currentLength => _captionController.text.length;

  String get _fullCaptionWithHashtags {
    String caption = _captionController.text.trim();
    
    if (_selectedHashtags.isNotEmpty) {
      if (caption.isNotEmpty && !caption.endsWith(' ')) {
        caption += ' ';
      }
      caption += _selectedHashtags.map((tag) => '#$tag').join(' ');
    }
    
    return caption;
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Error',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) Navigator.pop(context);
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================
  // 🔥 ЗАГРУЗКА ВИДЕО В R2 (с параллельной обработкой)
  // ============================================================
  Future<Map<String, String?>> _processVideo(String userId) async {
    print('🎬 [PROCESS] Starting parallel video processing...');
    final stopwatch = Stopwatch()..start();
    
    final videoFile = widget.selectedFiles.first;
    
    if (mounted) {
      setState(() {
        _uploadStatus = 'Compressing video...';
        _uploadProgress = 0.05;
      });
    }

    // 🔥 ПАРАЛЛЕЛЬНО: сжатие видео + генерация обложки
    // 🔥 ИСПРАВЛЕНО: передаём File, а не String
    final results = await Future.wait([
      VideoCompressor.compressVideo(videoFile),
      VideoCompressor.generateThumbnail(videoFile),
    ]);

    final compressedVideo = results[0] as File? ?? videoFile;
    final thumbnail = results[1] as File?;

    stopwatch.stop();
    print('⏱️ [PROCESS] Compression+Thumbnail took: ${stopwatch.elapsed.inSeconds} sec');

    if (mounted) {
      setState(() {
        _uploadStatus = 'Uploading video...';
        _uploadProgress = 0.3;
      });
    }

    // 🔥 ПАРАЛЛЕЛЬНО: загрузка видео и обложки
    final uploadStopwatch = Stopwatch()..start();
    
    final uploadTasks = <Future>[];
    String? videoUrl;
    String? thumbnailUrl;

    // Загрузка видео
    uploadTasks.add(() async {
      videoUrl = await _r2Service.uploadVideo(compressedVideo, userId);
    }());

    // Загрузка обложки (если есть)
    if (thumbnail != null) {
      uploadTasks.add(() async {
        thumbnailUrl = await _uploadThumbnailToStorage(thumbnail, userId);
      }());
    }

    await Future.wait(uploadTasks);
    uploadStopwatch.stop();
    
    print('⏱️ [PROCESS] Upload took: ${uploadStopwatch.elapsed.inSeconds} sec');
    print('⏱️ [PROCESS] TOTAL time: ${stopwatch.elapsed.inSeconds + uploadStopwatch.elapsed.inSeconds} sec');

    // Чистим временные файлы
    try {
      if (compressedVideo.path != videoFile.path) {
        await compressedVideo.delete();
      }
      if (thumbnail != null) {
        await thumbnail.delete();
      }
    } catch (e) {
      print('⚠️ [PROCESS] Could not delete temp files: $e');
    }

    return {
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  Future<String?> _uploadThumbnailToStorage(File thumbnail, String userId) async {
    try {
      final fileName = 'thumbnails/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child(fileName);
      await storageRef.putFile(thumbnail);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('❌ [UPLOAD] Thumbnail upload failed: $e');
      return null;
    }
  }

  // ============================================================
  // 🔥 ЗАГРУЗКА ФОТО (параллельно) — БЕЗОПАСНЫЙ setState
  // ============================================================
  Future<List<String>> _uploadPhotos(String userId) async {
    final int total = widget.selectedFiles.length;
    final List<Future<String?>> uploadFutures = [];

    for (int i = 0; i < total; i++) {
      final file = widget.selectedFiles[i];
      final index = i;

      uploadFutures.add(() async {
        try {
          final compressed = await ImageCompressor.compressImage(file);
          
          final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}_$index${path.extension(file.path)}';
          final storageRef = _storage.ref().child('posts').child(fileName);
          
          await storageRef.putFile(compressed);
          final url = await storageRef.getDownloadURL();
          
          if (compressed.path != file.path) {
            await compressed.delete();
          }
          
          if (mounted) {
            setState(() {
              _uploadStatus = 'Uploading photo ${index + 1}/$total...';
              _uploadProgress = 0.1 + ((index + 1) / total) * 0.7;
            });
          }
          
          return url;
        } catch (e) {
          print('❌ [UPLOAD] Photo $index failed: $e');
          return null;
        }
      }());
    }

    final results = await Future.wait(uploadFutures);
    return results.whereType<String>().toList();
  }

  Widget _buildVideoThumbnail() {
    if (_cachedThumbnail != null) {
      return Image.file(
        _cachedThumbnail!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[900],
            child: const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white54,
                size: 50,
              ),
            ),
          );
        },
      );
    }
    
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 ПУБЛИКАЦИЯ ПОСТА
  // ============================================================
  Future<void> _uploadPost() async {
    if (!mounted) return;
    if (_isUploading) return;
    
    final user = _auth.currentUser;
    if (user == null) {
      _showErrorDialog('You need to be logged in to post');
      return;
    }

    final fullCaption = _fullCaptionWithHashtags;
    
    if (fullCaption.length > _maxCaptionLength) {
      _showErrorDialog('Caption with hashtags is too long (max $_maxCaptionLength characters)');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparing...';
    });

    final totalStopwatch = Stopwatch()..start();

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!mounted) return;
      
      final userData = userDoc.data() ?? {};
      
      final String userName = userData['username'] ?? user.displayName ?? 'User';
      final String userAvatar = userData['avatarUrl'] ?? user.photoURL ?? '';

      final tagsJson = widget.tags.map((e) => e.toJson()).toList();

      final fitModesToSave = widget.fitModes ?? 
          List.filled(widget.selectedFiles.length, 'contain');

      String? videoUrl;
      String? thumbnailUrl;
      List<String> imageUrls = [];

      if (_isVideo) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('🎬 [CAPTION] ========== CREATING VIDEO POST ==========');
        print('🎬 [CAPTION] Username: $userName');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        final result = await _processVideo(user.uid);
        videoUrl = result['videoUrl'];
        thumbnailUrl = result['thumbnailUrl'];

        if (videoUrl == null) {
          throw Exception('Video upload failed');
        }

        if (mounted) {
          setState(() {
            _uploadProgress = 0.9;
            _uploadStatus = 'Saving post...';
          });
        }

        final docRef = _firestore.collection('posts').doc();
        final docId = docRef.id;
        
        final Map<String, dynamic> postData = {
          'id': docId,
          'userId': user.uid,
          'userName': userName,
          'userAvatar': userAvatar,
          'mediaType': 'video',
          'videoUrl': videoUrl,
          'thumbnailUrl': thumbnailUrl ?? '',
          'imageUrls': [thumbnailUrl ?? ''],
          'fitModes': fitModesToSave,
          'singleFitMode': fitModesToSave.isNotEmpty ? fitModesToSave.first : 'contain',
          'caption': fullCaption,
          'hashtags': _selectedHashtags,
          'likes': 0,
          'comments': 0,
          'saves': 0,
          'views': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active',
          'score': 0.0,
          'tags': tagsJson,
          'domainCategory': 'general',
          'clicks': 0,
          'hotScore': 0.0,
        };

        await docRef.set(postData);

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('userPosts')
            .doc(docId)
            .set({
              'postId': docId,
              'createdAt': FieldValue.serverTimestamp(),
            });

        final newPost = {
          'id': docId,
          ...postData,
          'createdAt': DateTime.now().toIso8601String(),
        };
        _postController.addPostsToStorage([newPost], markAsInFeed: true);

      } else {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📸 [CAPTION] ========== CREATING PHOTO POST ==========');
        print('📸 [CAPTION] Total images: ${widget.selectedFiles.length}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        imageUrls = await _uploadPhotos(user.uid);

        if (imageUrls.isEmpty) {
          throw Exception('Failed to upload images');
        }

        if (mounted) {
          setState(() {
            _uploadProgress = 0.95;
            _uploadStatus = 'Saving post...';
          });
        }

        final docRef = _firestore.collection('posts').doc();
        final docId = docRef.id;

        final Map<String, dynamic> postData = {
          'id': docId,
          'userId': user.uid,
          'userName': userName,
          'userAvatar': userAvatar,
          'mediaType': 'image',
          'imageUrls': imageUrls,
          'fitModes': fitModesToSave,
          'singleFitMode': fitModesToSave.isNotEmpty ? fitModesToSave.first : 'contain',
          'caption': fullCaption,
          'hashtags': _selectedHashtags,
          'likes': 0,
          'comments': 0,
          'saves': 0,
          'views': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active',
          'score': 0.0,
          'tags': tagsJson,
          'domainCategory': 'general',
          'clicks': 0,
          'hotScore': 0.0,
        };

        await docRef.set(postData);

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('userPosts')
            .doc(docId)
            .set({
              'postId': docId,
              'createdAt': FieldValue.serverTimestamp(),
            });

        final newPost = {
          'id': docId,
          ...postData,
          'createdAt': DateTime.now().toIso8601String(),
        };
        _postController.addPostsToStorage([newPost], markAsInFeed: true);
      }

      totalStopwatch.stop();
      print('⏱️ [CAPTION] TOTAL PUBLISH TIME: ${totalStopwatch.elapsed.inSeconds} sec');

      if (!mounted) return;
      
      setState(() {
        _uploadStatus = 'Success!';
        _uploadProgress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      
      try {
        Navigator.popUntil(context, (route) => route.isFirst);
        if (mounted) {
          _showSnackBar(
            _isVideo ? 'Video shared successfully!' : 'Post shared successfully!',
            Colors.green,
          );
        }
      } catch (e) {
        print('⚠️ [CAPTION] Navigation error: $e');
        if (mounted && context.mounted) {
          Navigator.pop(context);
        }
      }

    } catch (e) {
      print('❌ Error uploading post: $e');
      if (!mounted) return;
      _showErrorDialog('Failed to upload post: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isUploading,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            onPressed: _isUploading ? null : () {
              if (mounted) Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back,
              color: _isUploading ? Colors.grey[600] : Colors.white,
              size: 26,
            ),
          ),
          title: const Text(
            'Add Caption',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          actions: [
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              TextButton(
                onPressed: _uploadPost,
                child: const Text(
                  'Share',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        body: _isUploading
            ? Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: _uploadProgress,
                              color: Colors.white,
                              backgroundColor: Colors.grey[800],
                              strokeWidth: 4,
                            ),
                          ),
                          Text(
                            '${(_uploadProgress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _uploadStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.5,
                          child: AspectRatio(
                            aspectRatio: 4 / 5,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey[800]!,
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: widget.selectedFiles.isNotEmpty
                                    ? _isVideo
                                        ? _buildVideoThumbnail()
                                        : Image.file(
                                            widget.selectedFiles.first,
                                            fit: BoxFit.cover,
                                          )
                                    : Container(
                                        color: Colors.grey[800],
                                        child: Icon(
                                          _isVideo ? Icons.videocam : Icons.broken_image,
                                          color: Colors.grey,
                                          size: 50,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),

                      if (widget.selectedFiles.length > 1 && !_isVideo)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${widget.selectedFiles.length} photos selected',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                      if (widget.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.link, color: Colors.grey, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.tags.length} tags added',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 24),

                      TextField(
                        controller: _captionController,
                        maxLines: null,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Write a caption...',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                        ),
                        cursorColor: Colors.white,
                      ),

                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_currentLength/$_maxCaptionLength',
                                style: TextStyle(
                                  color: _currentLength > _maxCaptionLength 
                                      ? Colors.red 
                                      : _currentLength > _maxCaptionLength - 100 
                                          ? Colors.orange 
                                          : Colors.grey[400],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Hashtags',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      const SizedBox(height: 12),

                      if (_selectedHashtags.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedHashtags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '#$tag',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        if (mounted) {
                                          setState(() {
                                            _selectedHashtags.remove(tag);
                                          });
                                        }
                                      },
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.black,
                                        size: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _suggestedHashtags.map((tag) {
                          final isSelected = _selectedHashtags.contains(tag);
                          
                          if (isSelected) return const SizedBox.shrink();
                          
                          return GestureDetector(
                            onTap: () {
                              if (mounted) {
                                setState(() {
                                  _selectedHashtags.add(tag);
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.grey[700]!,
                                ),
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}