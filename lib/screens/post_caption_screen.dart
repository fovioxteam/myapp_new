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

  bool get _isVideo => widget.mediaType == MediaUploadType.video;

  @override
  void initState() {
    super.initState();
    _captionController.addListener(_updateRemainingChars);
    print('🔥 [CAPTION] INITIALIZED');
    print('🔥 [CAPTION] Media type: ${widget.mediaType}');
    print('🔥 [CAPTION] Total files: ${widget.selectedFiles.length}');
    print('🔥 [CAPTION] Tags count: ${widget.tags.length}');
  }

  @override
  void dispose() {
    _captionController.removeListener(_updateRemainingChars);
    _captionController.dispose();
    super.dispose();
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
  // 🔥 ЗАГРУЗКА ВИДЕО В R2
  // ============================================================
  Future<String?> _uploadVideoToR2(File videoFile, String userId) async {
    try {
      print('🎬 [UPLOAD] Starting video upload to R2...');
      
      setState(() {
        _uploadStatus = 'Uploading video to Cloudflare R2...';
      });
      
      final videoUrl = await _r2Service.uploadVideo(videoFile, userId);
      
      print('✅ [UPLOAD] Video uploaded: $videoUrl');
      return videoUrl;
      
    } catch (e) {
      print('❌ [UPLOAD] Video upload failed: $e');
      return null;
    }
  }

  // ============================================================
  // 🔥 ЗАГРУЗКА ПРЕВЬЮ ВИДЕО (thumbnail)
  // ============================================================
  Future<String?> _uploadThumbnail(File videoFile, String userId) async {
    try {
      print('🎬 [UPLOAD] Generating thumbnail...');
      
      final thumbnail = await VideoCompressor.getFileThumbnail(videoFile.path);
      
      if (thumbnail == null) {
        print('⚠️ [UPLOAD] Failed to generate thumbnail');
        return null;
      }
      
      final fileName = 'thumbnails/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child(fileName);
      await storageRef.putFile(thumbnail);
      final downloadUrl = await storageRef.getDownloadURL();
      
      print('✅ [UPLOAD] Thumbnail uploaded: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      print('❌ [UPLOAD] Thumbnail upload failed: $e');
      return null;
    }
  }

  // ============================================================
  // 🔥 ТАМБНЕЙЛ ДЛЯ ПРЕВЬЮ
  // ============================================================
  Future<File?> _getVideoThumbnailFile() async {
    try {
      final videoFile = widget.selectedFiles.first;
      final thumbnail = await VideoCompressor.getFileThumbnail(videoFile.path);
      return thumbnail;
    } catch (e) {
      print('❌ [THUMBNAIL] Error: $e');
      return null;
    }
  }

  Widget _buildVideoThumbnail() {
    return FutureBuilder<File?>(
      future: _getVideoThumbnailFile(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(
            snapshot.data!,
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
        
        // Пока грузится - показываем заглушку
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
      },
    );
  }

  // ============================================================
  // 🔥 ЗАГРУЗКА ПОСТА
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

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!mounted) return;
      
      final userData = userDoc.data() ?? {};
      
      final String userName = userData['username'] ?? user.displayName ?? 'User';
      final String userAvatar = userData['avatarUrl'] ?? user.photoURL ?? '';

      final tagsJson = widget.tags.map((e) => e.toJson()).toList();

      if (_isVideo) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('🎬 [CAPTION] ========== CREATING VIDEO POST ==========');
        print('🎬 [CAPTION] Username: $userName');
        print('🎬 [CAPTION] Tags count: ${widget.tags.length}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        setState(() {
          _uploadStatus = 'Uploading video...';
          _uploadProgress = 0.3;
        });
        
        final videoFile = widget.selectedFiles.first;
        
        final videoUrl = await _uploadVideoToR2(videoFile, user.uid);
        if (videoUrl == null) {
          throw Exception('Video upload failed');
        }
        
        print('🎬 [CAPTION] videoUrl from R2: $videoUrl');

        setState(() {
          _uploadProgress = 0.7;
          _uploadStatus = 'Generating thumbnail...';
        });
        
        final thumbnailUrl = await _uploadThumbnail(videoFile, user.uid);
        
        setState(() {
          _uploadProgress = 0.9;
          _uploadStatus = 'Saving post...';
        });
        
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

        print('🎬 [CAPTION] postData BEFORE saving: mediaType=${postData['mediaType']}, videoUrl=${postData['videoUrl']}');

        await docRef.set(postData);

        print('✅ [CAPTION] Video post saved with ID: $docId');

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
          'createdAt': DateTime.now(),
        };
        
        newPost['mediaType'] = 'video';
        newPost['videoUrl'] = videoUrl;
        newPost['thumbnailUrl'] = thumbnailUrl ?? '';

        print('🔍 [CAPTION] newPost before addPostsToStorage: mediaType=${newPost['mediaType']}, videoUrl=${newPost['videoUrl']}');

        _postController.addPostsToStorage([newPost], markAsInFeed: true);

      } else {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📸 [CAPTION] ========== CREATING PHOTO POST ==========');
        print('📸 [CAPTION] Username: $userName');
        print('📸 [CAPTION] Total images: ${widget.selectedFiles.length}');
        print('📸 [CAPTION] Tags count: ${widget.tags.length}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        List<String> imageUrls = [];
        List<int> failedUploads = [];

        for (int i = 0; i < widget.selectedFiles.length; i++) {
          if (!mounted) return;
          
          final originalFile = widget.selectedFiles[i];
          final beforeSize = await ImageCompressor.getFileSizeString(originalFile);
          print('📸 [UPLOAD] Image $i: Before compression = $beforeSize');
          
          final file = await ImageCompressor.compressImage(
            originalFile,
            maxWidth: 900,
            maxHeight: 1600,
            quality: 75,
          );
          
          final afterSize = await ImageCompressor.getFileSizeString(file);
          print('📸 [UPLOAD] Image $i: After compression = $afterSize');
          
          setState(() {
            _uploadStatus = 'Uploading image ${i + 1}/${widget.selectedFiles.length}...';
          });
          
          try {
            final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}_$i${path.extension(file.path)}';
            final storageRef = _storage.ref().child('posts').child(fileName);
            
            final uploadTask = storageRef.putFile(file);
            
            uploadTask.snapshotEvents.listen((snapshot) {
              if (!mounted) return;
              final progress = snapshot.bytesTransferred / snapshot.totalBytes;
              setState(() {
                _uploadProgress = (i + progress) / widget.selectedFiles.length;
              });
            });
            
            await uploadTask;
            
            if (!mounted) return;
            
            String downloadUrl;
            try {
              downloadUrl = await storageRef.getDownloadURL();
            } catch (e) {
              print('❌ Failed to get download URL for image $i: $e');
              failedUploads.add(i);
              continue;
            }
            
            if (downloadUrl.isEmpty) {
              print('❌ Empty download URL for image $i');
              failedUploads.add(i);
              continue;
            }
            
            imageUrls.add(downloadUrl);
            print('✅ Image $i uploaded successfully');
            
          } catch (e) {
            print('❌ Error uploading image $i: $e');
            failedUploads.add(i);
          }
        }

        if (imageUrls.isEmpty) {
          throw Exception('Failed to upload images');
        }

        setState(() {
          _uploadStatus = 'Saving post...';
          _uploadProgress = 0.95;
        });

        final fitModesToSave = widget.fitModes ?? 
            List.filled(widget.selectedFiles.length, 'contain');

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

        print('📦 [CAPTION] Saving photo post to Firestore...');
        
        await docRef.set(postData);
        
        print('✅ [CAPTION] Photo post saved with ID: $docId');

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
          'createdAt': DateTime.now(),
        };
        _postController.addPostsToStorage([newPost], markAsInFeed: true);
      }

      if (!mounted) return;
      
      setState(() {
        _uploadStatus = 'Success!';
        _uploadProgress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      
      try {
        if (mounted && context.mounted) {
          Navigator.popUntil(context, (route) {
            return route.settings.name == '/feed' || route.isFirst;
          });
          
          if (mounted) {
            Get.find<ProfileController>().update();
          }
          
          if (mounted) {
            _showSnackBar(
              _isVideo ? 'Video shared successfully!' : 'Post shared successfully!',
              Colors.green,
            );
          }
        }
      } catch (e) {
        print('⚠️ [CAPTION] Navigation error (ignored): $e');
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
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
                    // ============================================================
                    // 🔥 ПРЕВЬЮ - ТАМБНЕЙЛ ВИДЕО ИЛИ ФОТО (БЕЗ ИКОНКИ PLAY)
                    // ============================================================
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
    );
  }
}