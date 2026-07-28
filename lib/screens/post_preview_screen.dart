// lib/screens/post_preview_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'post_caption_screen.dart';
import '../controllers/post_controller.dart';
import '../models/post_tag.dart';
import '../widgets/tag_editor_widget.dart';
import '../widgets/post_tags_overlay.dart';
import 'webview_screen.dart';

const int maxTagsPerPost = 10;

class PostPreviewScreen extends StatefulWidget {
  final List<File> selectedFiles;
  final List<AssetEntity>? selectedAssets;
  final File? cameraImage;

  const PostPreviewScreen({
    super.key,
    required this.selectedFiles,
    this.selectedAssets,
    this.cameraImage,
  });

  @override
  State<PostPreviewScreen> createState() => _PostPreviewScreenState();
}

class _PostPreviewScreenState extends State<PostPreviewScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PostController _postController = Get.find<PostController>();
  
  late PageController _pageController;
  int _currentIndex = 0;
  
  bool _isZoomed = false;
  final TransformationController _transformationController = TransformationController();
  final Map<int, BoxFit> _fitModeForIndex = {};
  final Map<int, Matrix4> _transformations = {};

  final List<PostTag> _tags = [];
  double? _tapX;
  double? _tapY;

  Timer? _moveTimer;
  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    for (int i = 0; i < widget.selectedFiles.length; i++) {
      _fitModeForIndex[i] = BoxFit.contain;
      _transformations[i] = Matrix4.identity();
    }
    
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📱 [PREVIEW] ========== POST PREVIEW SCREEN INITIALIZED ==========');
    print('📱 [PREVIEW] Total images: ${widget.selectedFiles.length}');
    print('📱 [PREVIEW] Initial fit modes: $_fitModeForIndex');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    _moveTimer?.cancel();
    super.dispose();
  }

  void _toggleFitMode() {
    setState(() {
      final currentFit = _fitModeForIndex[_currentIndex] ?? BoxFit.contain;
      
      if (currentFit == BoxFit.contain) {
        _fitModeForIndex[_currentIndex] = BoxFit.cover;
      } else {
        _fitModeForIndex[_currentIndex] = BoxFit.contain;
        _transformations[_currentIndex] = Matrix4.identity();
        _transformationController.value = Matrix4.identity();
      }
      
      print('🔄 [PREVIEW] Toggle fit mode for image $_currentIndex: ${_fitModeForIndex[_currentIndex]}');
    });
  }

  void _saveTransformation() {
    _transformations[_currentIndex] = _transformationController.value;
  }

  void _resetTransformations() {
    setState(() {
      _transformations[_currentIndex] = Matrix4.identity();
      _transformationController.value = Matrix4.identity();
      _fitModeForIndex[_currentIndex] = BoxFit.contain;
      _isZoomed = false;
    });
    print('🔄 [PREVIEW] Reset transformations for image $_currentIndex');
  }

  void _navigateToCaption() {
    final List<String> fitModes = [];
    for (int i = 0; i < widget.selectedFiles.length; i++) {
      final fit = _fitModeForIndex[i] ?? BoxFit.contain;
      fitModes.add(fit == BoxFit.contain ? 'contain' : 'cover');
    }
    
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📱 [PREVIEW] ========== NAVIGATING TO CAPTION ==========');
    print('📱 [PREVIEW] Total images: ${widget.selectedFiles.length}');
    print('📱 [PREVIEW] fitModes: $fitModes');
    print('📱 [PREVIEW] Tags count: ${_tags.length}');
    
    if (_tags.isNotEmpty) {
      print('📱 [PREVIEW] Tags details:');
      for (var tag in _tags) {
        print('   - id: ${tag.id}, x: ${tag.x}, y: ${tag.y}, url: ${tag.url}, platform: ${tag.platform}');
      }
    }
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostCaptionScreen(
          selectedFiles: widget.selectedFiles,
          fitModes: fitModes,
          tags: _tags,
        ),
      ),
    ).then((_) {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        _postController.refreshUserPosts(currentUser.uid);
      }
    });
  }

  void _onImageTap(double x, double y) {
    if (_tags.length >= maxTagsPerPost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $maxTagsPerPost tags per post'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📍 [PREVIEW] ========== ADDING NEW TAG ==========');
    print('📍 [PREVIEW] Image index: $_currentIndex');
    print('📍 [PREVIEW] Tap position: ($x, $y) (percentage)');
    print('📍 [PREVIEW] Current fit mode: ${_fitModeForIndex[_currentIndex] ?? BoxFit.contain}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    setState(() {
      _tapX = x;
      _tapY = y;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TagEditorWidget(
        x: x,
        y: y,
        onSave: (tag) {
          setState(() {
            final tagWithIndex = PostTag(
              id: '${tag.id}_$_currentIndex',
              x: tag.x,
              y: tag.y,
              url: tag.url,
              platform: tag.platform,
              displayName: tag.displayName,
            );
            _tags.add(tagWithIndex);
            _tapX = null;
            _tapY = null;
            
            print('✅ [PREVIEW] Tag added successfully!');
            print('   - id: ${tagWithIndex.id}');
            print('   - x: ${tagWithIndex.x}');
            print('   - y: ${tagWithIndex.y}');
            print('   - url: ${tagWithIndex.url}');
            print('   - platform: ${tagWithIndex.platform}');
            print('   - Total tags now: ${_tags.length}');
          });
        },
        onCancel: () {
          setState(() {
            _tapX = null;
            _tapY = null;
          });
          print('❌ [PREVIEW] Tag addition cancelled');
        },
      ),
    );
  }

  void _onTagMoved(PostTag tag, double newX, double newY) {
    print('📍 [PREVIEW] Tag moved: ${tag.id} -> ($newX, $newY)');
    tag.updatePosition(newX, newY);
    
    if (!_isMoving) {
      _isMoving = true;
      _moveTimer?.cancel();
      _moveTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _isMoving = false;
          });
        }
      });
    }
  }

  // ============================================================
  // 🔥 _buildImageItem — С ФИЛЬТРАЦИЕЙ ПО ИНДЕКСУ
  // ============================================================
  Widget _buildImageItem(File file, BoxFit fitMode, int imageIndex) {
    final isFullScreen = fitMode == BoxFit.cover;

    // 👇 ФИЛЬТРУЕМ ТЭГИ ТОЛЬКО ДЛЯ ЭТОГО ИЗОБРАЖЕНИЯ
    final tagsForThisImage = _tags.where((tag) => tag.id.contains('_$imageIndex')).toList();

    return Container(
      color: Colors.black,
      child: isFullScreen
          ? _buildFullImage(file, tagsForThisImage)
          : _buildAutoImage(file, tagsForThisImage),
    );
  }

  Widget _buildAutoImage(File file, List<PostTag> tagsForThisImage) {
    return Center(
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              file,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
            if (tagsForThisImage.isNotEmpty)
              PostTagsOverlay(
                tags: tagsForThisImage,
                isVisible: true,
                onTagTap: (tag) {
                  print('🔗 [PREVIEW] Tag tapped: ${tag.url}');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WebViewScreen(
                        url: tag.url,
                        title: tag.displayName,
                      ),
                    ),
                  );
                },
                onTagMoved: _onTagMoved,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullImage(File file, List<PostTag> tagsForThisImage) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.file(
            file,
            fit: BoxFit.cover,
          ),
        ),
        if (tagsForThisImage.isNotEmpty)
          PostTagsOverlay(
            tags: tagsForThisImage,
            isVisible: true,
            onTagTap: (tag) {
              print('🔗 [PREVIEW] Tag tapped: ${tag.url}');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WebViewScreen(
                    url: tag.url,
                    title: tag.displayName,
                  ),
                ),
              );
            },
            onTagMoved: _onTagMoved,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.horizontal,
              itemCount: widget.selectedFiles.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _transformationController.value = _transformations[index] ?? Matrix4.identity();
                  _isZoomed = false;
                });
                print('📄 [PREVIEW] Page changed to index: $index');
              },
              itemBuilder: (context, index) {
                final file = widget.selectedFiles[index];
                final currentFit = _fitModeForIndex[index] ?? BoxFit.contain;
                
                return _buildImageItem(file, currentFit, index);
              },
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 16,
                right: 16,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Preview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_tags.isNotEmpty)
                        Text(
                          '${_tags.length} tags',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  TextButton(
                    onPressed: _navigateToCaption,
                    child: Text(
                      _tags.isEmpty ? 'Next' : 'Next (${_tags.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.grey[700]!,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeButton(
                          icon: Icons.aspect_ratio,
                          label: 'Auto',
                          isActive: (_fitModeForIndex[_currentIndex] ?? BoxFit.contain) == BoxFit.contain,
                          onTap: _toggleFitMode,
                        ),
                        _buildModeButton(
                          icon: Icons.fullscreen,
                          label: 'Full',
                          isActive: (_fitModeForIndex[_currentIndex] ?? BoxFit.contain) == BoxFit.cover,
                          onTap: _toggleFitMode,
                        ),
                      ],
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.grey[700],
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    _buildAddLinkButton(),
                  ],
                ),
              ),
            ),
          ),

          if (widget.selectedFiles.length > 1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Center(
                    child: SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: widget.selectedFiles.length,
                        itemBuilder: (context, index) {
                          final isSelected = _currentIndex == index;
                          final file = widget.selectedFiles[index];
                          
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  file,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          
          if (_isZoomed)
            Positioned(
              bottom: 160,
              right: 16,
              child: GestureDetector(
                onTap: _resetTransformations,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey[700]!,
                      width: 0.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.black : Colors.white,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddLinkButton() {
    return GestureDetector(
      onTap: () => _onImageTap(0.5, 0.5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.add,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              'Add Link',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}