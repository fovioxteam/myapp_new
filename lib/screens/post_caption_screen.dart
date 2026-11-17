// lib/screens/post_caption_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:video_transcoder/video_transcoder.dart';

import '../controllers/post_controller.dart';
import '../models/post_tag.dart';
import '../models/media_types.dart';
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

    if (_isVideo) {
      _preloadThumbnail();
    }
  }

  @override
  void dispose() {
    _captionController.removeListener(_updateRemainingChars);
    _captionController.dispose();

    if (_cachedThumbnail != null && _cachedThumbnail!.existsSync()) {
      try {
        _cachedThumbnail!.delete();
      } catch (_) {}
    }
    _cachedThumbnail = null;

    super.dispose();
  }

  Future<void> _preloadThumbnail() async {
    if (_cachedThumbnail != null || _thumbnailLoading) return;

    setState(() => _thumbnailLoading = true);

    try {
      final videoFile = widget.selectedFiles.first;

      File? thumb = await VideoTranscoder.generateThumbnail(
        videoFile,
        timeMs: 500,
      );

      thumb ??= await VideoCompressor.generateThumbnail(videoFile);

      if (mounted) {
        setState(() {
          _cachedThumbnail = thumb;
          _thumbnailLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _thumbnailLoading = false);
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
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: Colors.blue)),
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
  // 🔥 ЗАГРУЗКА ВИДЕО (native сжатие через VideoTranscoder)
  // ============================================================
  Future<Map<String, String?>> _processVideo(String userId) async {
    final videoFile = widget.selectedFiles.first;

    if (mounted) {
      setState(() {
        _uploadStatus = 'Converting video...';
        _uploadProgress = 0.10;
      });
    }

    // Native сжатие через VideoTranscoder (iOS AVAssetExportSession 720p)
    // Автоматически делает HDR → SDR + уменьшает размер до ~15-25 MB
    File? compressedVideo;

    try {
      final result = await VideoTranscoder.transcodeForUpload(
        videoFile,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = 0.10 + progress * 0.15;
            });
          }
        },
      );
      compressedVideo = File(result.path);
      debugPrint('✅ [PROCESS] Native transcode done. wasTranscoded=${result.wasTranscoded}');
    } on MissingPluginException {
      debugPrint('⚠️ [PROCESS] Native plugin unavailable, using FFmpeg');
      compressedVideo = await VideoCompressor.compressVideo(videoFile);
    } catch (e) {
      debugPrint('⚠️ [PROCESS] Native transcode failed: $e, using FFmpeg');
      compressedVideo = await VideoCompressor.compressVideo(videoFile);
    }

    if (compressedVideo == null) {
      throw Exception('Video compression failed');
    }

    // Thumbnail
    File? thumbnail = _cachedThumbnail;
    if (thumbnail == null || !thumbnail.existsSync()) {
      thumbnail = await VideoCompressor.generateThumbnail(compressedVideo);
    }

    if (mounted) {
      setState(() {
        _uploadStatus = 'Uploading video...';
        _uploadProgress = 0.25;
      });
    }

    String? videoUrl;
    String? thumbnailUrl;

    try {
      videoUrl = await _r2Service.uploadVideo(
        compressedVideo,
        userId,
        onProgress: (sent, total) {
          if (mounted && total > 0) {
            setState(() {
              _uploadProgress = 0.25 + ((sent / total) * 0.60);
            });
          }
        },
      );
    } catch (e) {
      debugPrint('❌ [PROCESS] Video upload failed: $e');
    }

    if (thumbnail != null && await thumbnail.exists()) {
      try {
        thumbnailUrl = await _uploadThumbnailToStorage(thumbnail, userId);
      } catch (e) {
        debugPrint('❌ [PROCESS] Thumbnail upload failed: $e');
      }
    }

    // Очистка
    try {
      if (compressedVideo.path != videoFile.path) {
        await compressedVideo.delete();
      }
    } catch (_) {}

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
      debugPrint('❌ [UPLOAD] Thumbnail upload failed: $e');
      return null;
    }
  }

  // ============================================================
  // ПАРАЛЛЕЛЬНАЯ ЗАГРУЗКА ФОТО С ТОЧНЫМ PROGRESS BAR
  // ============================================================
  Future<List<String>> _uploadPhotos(String userId) async {
    final int total = widget.selectedFiles.length;
    final List<double> individualProgress = List.filled(total, 0.0);
    final List<Future<String?>> uploadFutures = [];

    for (int i = 0; i < total; i++) {
      final file = widget.selectedFiles[i];
      final index = i;

      uploadFutures.add(() async {
        File? compressed;
        try {
          compressed = await ImageCompressor.compressImage(file);
          final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}_$index${path.extension(file.path)}';
          final storageRef = _storage.ref().child('posts').child(fileName);

          final uploadTask = storageRef.putFile(compressed);

          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            if (snapshot.totalBytes > 0) {
              individualProgress[index] = snapshot.bytesTransferred / snapshot.totalBytes;
              final double avgProgress = individualProgress.reduce((a, b) => a + b) / total;
              if (mounted) {
                setState(() {
                  _uploadStatus = 'Uploading photos (${(avgProgress * 100).toInt()}%)...';
                  _uploadProgress = 0.1 + (avgProgress * 0.8);
                });
              }
            }
          });

          final snapshot = await uploadTask;
          return await snapshot.ref.getDownloadURL();
        } catch (e) {
          debugPrint('❌ [UPLOAD] Photo $index failed: $e');
          return null;
        } finally {
          if (compressed != null && compressed.path != file.path && compressed.existsSync()) {
            try { await compressed.delete(); } catch (_) {}
          }
        }
      }());
    }

    final results = await Future.wait(uploadFutures);
    return results.whereType<String>().toList();
  }

  // ============================================================
  // ПРЕВЬЮ ВИДЕО
  // ============================================================
  Widget _buildVideoThumbnail() {
    if (_cachedThumbnail != null && _cachedThumbnail!.existsSync()) {
      return Image.file(
        _cachedThumbnail!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildVideoFallback(),
      );
    }

    if (_thumbnailLoading) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
        ),
      );
    }

    return _buildVideoFallback();
  }

  Widget _buildVideoFallback() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam, color: Colors.white54, size: 60),
            SizedBox(height: 12),
            Text('Video selected', style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ПУБЛИКАЦИЯ
  // ============================================================
  Future<void> _uploadPost() async {
    if (!mounted || _isUploading) return;

    final user = _auth.currentUser;
    if (user == null) {
      _showErrorDialog('You need to be logged in to post');
      return;
    }

    final fullCaption = _fullCaptionWithHashtags;
    if (fullCaption.length > _maxCaptionLength) {
      _showErrorDialog('Caption is too long (max $_maxCaptionLength characters)');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
      _uploadStatus = 'Preparing content...';
    });

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!mounted) return;

      final userData = userDoc.data() ?? {};
      final String userName = userData['username'] ?? user.displayName ?? 'User';
      final String userAvatar = userData['avatarUrl'] ?? user.photoURL ?? '';
      final tagsJson = widget.tags.map((e) => e.toJson()).toList();
      final fitModesToSave = widget.fitModes ?? List.filled(widget.selectedFiles.length, 'contain');

      final docRef = _firestore.collection('posts').doc();
      final docId = docRef.id;

      Map<String, dynamic> postData = {
        'id': docId,
        'userId': user.uid,
        'userName': userName,
        'userAvatar': userAvatar,
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

      if (_isVideo) {
        final result = await _processVideo(user.uid);
        final videoUrl = result['videoUrl'];
        final thumbnailUrl = result['thumbnailUrl'] ?? '';

        if (videoUrl == null || videoUrl.isEmpty) {
          throw Exception('Video upload failed.');
        }

        postData.addAll({
          'mediaType': 'video',
          'videoUrl': videoUrl,
          'thumbnailUrl': thumbnailUrl,
          'imageUrls': [thumbnailUrl],
        });
      } else {
        final imageUrls = await _uploadPhotos(user.uid);
        if (imageUrls.isEmpty) throw Exception('Failed to upload images');

        postData.addAll({
          'mediaType': 'image',
          'imageUrls': imageUrls,
        });
      }

      if (mounted) {
        setState(() {
          _uploadProgress = 0.95;
          _uploadStatus = 'Saving post...';
        });
      }

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

      _postController.addPostsToStorage([
        {
          ...postData,
          'createdAt': DateTime.now().toIso8601String(),
        }
      ], markAsInFeed: true);

      if (!mounted) return;
      setState(() {
        _uploadStatus = 'Success!';
        _uploadProgress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      Navigator.popUntil(context, (route) => route.isFirst);
      _showSnackBar(_isVideo ? 'Video shared!' : 'Post shared!', Colors.green);

    } catch (e) {
      debugPrint('❌ Error uploading post: $e');
      _showErrorDialog('Failed to upload post: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
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
            onPressed: _isUploading ? null : () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back,
              color: _isUploading ? Colors.grey[700] : Colors.white,
              size: 26,
            ),
          ),
          title: const Text(
            'Add Caption',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          actions: [
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              )
            else
              TextButton(
                onPressed: _uploadPost,
                child: const Text(
                  'Share',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        body: _isUploading
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
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
                        style: const TextStyle(color: Colors.white, fontSize: 14),
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
                      // Превью
                      Center(
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.5,
                          child: AspectRatio(
                            aspectRatio: 4 / 5,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[800]!, width: 1),
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

                      // Инфо о количестве
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
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ),
                        ),

                      // Инфо о тегах
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
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // ✅ TextField с прозрачным фоном (как было)
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

                      // Счётчик символов
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
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),

                      const SizedBox(height: 12),

                      // Выбранные хэштеги
                      if (_selectedHashtags.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedHashtags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                          setState(() => _selectedHashtags.remove(tag));
                                        }
                                      },
                                      child: const Icon(Icons.close, color: Colors.black, size: 14),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // Предложенные хэштеги
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _suggestedHashtags.map((tag) {
                          final isSelected = _selectedHashtags.contains(tag);
                          if (isSelected) return const SizedBox.shrink();

                          return GestureDetector(
                            onTap: () {
                              if (mounted) {
                                setState(() => _selectedHashtags.add(tag));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey[700]!),
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(color: Colors.grey[400], fontSize: 13),
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