import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

import '../controllers/post_controller.dart';
import '../extensions/safe_extensions.dart';

class PostOptionsScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onPostDeleted;
  final bool isFromFeed;

  const PostOptionsScreen({
    super.key,
    required this.post,
    this.onPostDeleted,
    this.isFromFeed = false,
  });

  @override
  State<PostOptionsScreen> createState() => _PostOptionsScreenState();
}

class _PostOptionsScreenState extends State<PostOptionsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PostController _postController = Get.find<PostController>();

  bool _isDeleting = false;
  bool _isSharing = false;
  bool _isSaving = false;
  bool _isReporting = false;
  String? _selectedReportReason;
  String? _customReportReason;

  String? get _currentUserId => _auth.currentUser?.uid;
  String? get _postUserId => widget.post['userId']?.toString();
  bool get _isOwnPost => _currentUserId != null && _currentUserId == _postUserId;

  final List<String> _reportReasons = [
    'Spam',
    'Harassment or bullying',
    'Child safety concerns',
    'Hate speech',
    'Inappropriate content',
    'False information',
    'Impersonation',
    'Violence or dangerous content',
    'Intellectual property violation',
    'Other',
  ];

  // ============================================================
  // 🔥 ПРОВЕРКА - ВИДЕО ЛИ ЭТО
  // ============================================================
  bool _isVideoPost() {
    final mediaType = widget.post['mediaType']?.toString() ?? '';
    if (mediaType == 'video') return true;
    
    final videoUrl = widget.post['videoUrl']?.toString() ?? '';
    if (videoUrl.isNotEmpty) return true;
    
    return false;
  }

  // ============================================================
  // 🔥 ПОЛУЧЕНИЕ URL ДЛЯ СОХРАНЕНИЯ
  // ============================================================
  String? _getMediaUrl() {
    // Для видео
    if (_isVideoPost()) {
      final videoUrl = widget.post['videoUrl']?.toString();
      if (videoUrl != null && videoUrl.isNotEmpty) {
        return videoUrl;
      }
    }
    
    // Для фото
    String? imageUrl = widget.post['imageUrl']?.toString();
    if (imageUrl == null || imageUrl.isEmpty) {
      imageUrl = widget.post['url']?.toString();
    }
    if (imageUrl == null || imageUrl.isEmpty) {
      final imageUrls = widget.post['imageUrls'];
      if (imageUrls is List && imageUrls.isNotEmpty) {
        imageUrl = imageUrls[0]?.toString();
      }
    }
    
    return imageUrl;
  }

  // ============================================================
  // 🔥 ДИАЛОГ РАЗРЕШЕНИЙ
  // ============================================================
  Future<bool?> _showPermissionDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Storage Permission Needed',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Please allow access to save media to your gallery',
          style: TextStyle(color: Colors.white70),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 СОХРАНЕНИЕ ВИДЕО
  // ============================================================
  Future<void> _saveVideo(String videoUrl) async {
    try {
      print('🎬 [SAVE] Starting video download: $videoUrl');
      
      PermissionState perm = await PhotoManager.requestPermissionExtend();
      if (!perm.isAuth) {
        final shouldOpenSettings = await _showPermissionDialog();
        if (shouldOpenSettings == true) {
          await PhotoManager.openSetting();
          perm = await PhotoManager.requestPermissionExtend();
        }
      }
      
      if (!perm.isAuth) {
        _showToast('Cannot save video without storage permission', isError: true);
        return;
      }

      setState(() => _isSaving = true);

      final response = await Dio().get(
        videoUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      
      final bytes = response.data as Uint8List;
      
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/foviox_video_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await tempFile.writeAsBytes(bytes);
      
      final assetEntity = await PhotoManager.editor.saveVideo(
        tempFile,
        title: "foviox_video_${DateTime.now().millisecondsSinceEpoch}.mp4",
      );
      
      await tempFile.delete();
      
      if (assetEntity != null) {
        _showToast('Video saved to gallery');
        print('✅ [SAVE] Video saved: ${assetEntity.id}');
      } else {
        throw Exception('Failed to save video');
      }

    } catch (e) {
      print('❌ [SAVE] Error saving video: $e');
      _showToast('Failed to save video: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============================================================
  // 🔥 СОХРАНЕНИЕ ИЗОБРАЖЕНИЯ
  // ============================================================
  Future<void> _saveImage(String imageUrl) async {
    try {
      print('📸 [SAVE] Starting image download: $imageUrl');
      
      PermissionState perm = await PhotoManager.requestPermissionExtend();
      if (!perm.isAuth) {
        final shouldOpenSettings = await _showPermissionDialog();
        if (shouldOpenSettings == true) {
          await PhotoManager.openSetting();
          perm = await PhotoManager.requestPermissionExtend();
        }
      }
      
      if (!perm.isAuth) {
        _showToast('Cannot save image without storage permission', isError: true);
        return;
      }

      setState(() => _isSaving = true);

      final response = await Dio().get(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      
      Uint8List bytes = response.data;

      if (bytes.length > 1024 * 1024) {
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          quality: 85,
        );
        if (compressed != null) bytes = compressed;
      }

      await PhotoManager.editor.saveImage(
        bytes,
        title: "foviox_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );
      
      _showToast('Image saved to gallery');

    } catch (e) {
      print('❌ [SAVE] Error saving image: $e');
      _showToast('Failed to save image: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============================================================
  // 🔥 ОСНОВНОЙ МЕТОД СОХРАНЕНИЯ - "SAVE POST"
  // ============================================================
  Future<void> _savePost() async {
    if (_isSaving) return;

    final mediaUrl = _getMediaUrl();
    if (mediaUrl == null || mediaUrl.isEmpty) {
      _showToast('No media to save', isError: true);
      return;
    }

    if (_isVideoPost()) {
      await _saveVideo(mediaUrl);
    } else {
      await _saveImage(mediaUrl);
    }
  }

  // ============================================================
  // 🔥 ОСТАЛЬНЫЕ МЕТОДЫ
  // ============================================================
  
  void _showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.red : Colors.black,
      textColor: Colors.white,
    );
  }

  Future<void> _reportPost() async {
    if (_isReporting) return;

    final postId = widget.post['id']?.toString();
    if (postId == null) return;

    _selectedReportReason = null;
    _customReportReason = null;

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Report Post',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Why are you reporting this post?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 350),
                    child: SingleChildScrollView(
                      child: Column(
                        children: _reportReasons.map((reason) {
                          final isSelected = _selectedReportReason == reason;
                          return RadioListTile<String>(
                            title: Text(
                              reason,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                              ),
                            ),
                            value: reason,
                            groupValue: _selectedReportReason,
                            activeColor: Colors.white,
                            onChanged: (value) {
                              setDialogState(() {
                                _selectedReportReason = value;
                                if (value != 'Other') {
                                  _customReportReason = null;
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  if (_selectedReportReason == 'Other') ...[
                    const SizedBox(height: 8),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Please specify...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[700]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          _customReportReason = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () {
                  if (_selectedReportReason == null) {
                    _showToast('Please select a reason', isError: true);
                    return;
                  }
                  if (_selectedReportReason == 'Other' && 
                      (_customReportReason == null || _customReportReason!.trim().isEmpty)) {
                    _showToast('Please specify the reason', isError: true);
                    return;
                  }
                  Navigator.pop(context, {
                    'reason': _selectedReportReason!,
                    'details': _selectedReportReason == 'Other' 
                        ? _customReportReason!.trim() 
                        : '',
                  });
                },
                child: const Text('Submit', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    setState(() => _isReporting = true);

    try {
      await _firestore.collection('reports').add({
        'postId': postId,
        'postOwnerId': _postUserId,
        'reporterId': _currentUserId,
        'reason': result['reason'],
        'details': result['details'] ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (_currentUserId != null) {
        await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('reports')
            .add({
          'postId': postId,
          'postOwnerId': _postUserId,
          'reason': result['reason'],
          'details': result['details'] ?? '',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _showToast('Post reported successfully');

    } catch (e) {
      print('❌ Report error: $e');
      _showToast('Failed to report', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isReporting = false);
        Get.back();
      }
    }
  }

  Future<void> _deletePost() async {
    if (_isDeleting) return;

    final postId = widget.post['id']?.toString();
    if (postId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Post?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This action cannot be undone',
          style: TextStyle(color: Colors.white70),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    _postController.removePostFromAllLists(postId);
    Get.back();
    widget.onPostDeleted?.call();

    _postController.deletePost(postId).catchError((e) {
      print('❌ Delete error: $e');
      _showToast('Delete failed', isError: true);
    });

    _showToast('Post deleted');
    setState(() => _isDeleting = false);
  }

  Future<void> _sharePost() async {
    setState(() => _isSharing = true);

    try {
      final postId = widget.post['id']?.toString();
      if (postId == null) return;

      final link = 'https://foviox.com/post/$postId';
      await Share.share(link);
    } catch (_) {
      _showToast('Share error', isError: true);
    }

    if (mounted) {
      setState(() => _isSharing = false);
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 ОДНА ИКОНКА И ОДИН ТЕКСТ ДЛЯ ВСЕХ ТИПОВ ПОСТОВ
    const saveIcon = CupertinoIcons.arrow_down_doc;
    const saveLabel = 'Save Post';
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Список опций
            if (_isOwnPost)
              _buildOption(
                icon: CupertinoIcons.delete,
                label: _isDeleting ? 'Deleting...' : 'Delete Post',
                onTap: _isDeleting ? null : _deletePost,
              ),

            if (_isOwnPost) const Divider(color: Color.fromARGB(255, 0, 0, 0)),

            _buildOption(
              icon: CupertinoIcons.share,
              label: _isSharing ? 'Sharing...' : 'Share',
              onTap: _isSharing ? null : _sharePost,
            ),

            _buildOption(
              icon: saveIcon,
              label: _isSaving ? 'Saving...' : saveLabel,
              onTap: _isSaving ? null : _savePost,
            ),

            // 🔥 REPORT ВСЕГДА ПОСЛЕДНИЙ (как и было)
            if (!_isOwnPost) ...[
              const Divider(color: Color.fromARGB(255, 0, 0, 0)),
              _buildOption(
                icon: CupertinoIcons.flag,
                label: _isReporting ? 'Reporting...' : 'Report',
                onTap: _isReporting ? null : _reportPost,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return CupertinoButton(
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: onTap == null ? Colors.grey[600] : Colors.white),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              color: onTap == null ? Colors.grey[600] : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}