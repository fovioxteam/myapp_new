import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/media_types.dart';
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
  final MediaUploadType mediaType;

  const PostPreviewScreen({
    super.key,
    required this.selectedFiles,
    this.selectedAssets,
    this.cameraImage,
    this.mediaType = MediaUploadType.image,
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

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;

  bool get _isVideo => widget.mediaType == MediaUploadType.video;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    for (int i = 0; i < widget.selectedFiles.length; i++) {
      _fitModeForIndex[i] = BoxFit.contain;
      _transformations[i] = Matrix4.identity();
    }

    if (_isVideo && widget.selectedFiles.isNotEmpty) {
      _initVideoPlayer();
    }
    
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📱 [PREVIEW] ========== POST PREVIEW SCREEN INITIALIZED ==========');
    print('📱 [PREVIEW] Media type: ${widget.mediaType}');
    print('📱 [PREVIEW] Total files: ${widget.selectedFiles.length}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    _moveTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideoPlayer() async {
    try {
      final file = widget.selectedFiles.first;
      _videoController = VideoPlayerController.file(file);
      
      await _videoController!.initialize();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController!.play();
        _videoController!.setLooping(true);
        _isVideoPlaying = true;
      }
      
      print('✅ [VIDEO] Initialized, duration: ${_videoController!.value.duration}');
    } catch (e) {
      print('❌ [VIDEO] Failed to initialize: $e');
    }
  }

  void _toggleVideoPlayback() {
    if (_videoController == null || !_isVideoInitialized) return;
    
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isVideoPlaying = false;
      } else {
        _videoController!.play();
        _isVideoPlaying = true;
      }
    });
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
    print('📱 [PREVIEW] Media type: ${widget.mediaType}');
    print('📱 [PREVIEW] Total files: ${widget.selectedFiles.length}');
    print('📱 [PREVIEW] Tags count: ${_tags.length}');
    
    if (_tags.isNotEmpty) {
      print('📱 [PREVIEW] Tags details:');
      for (var tag in _tags) {
        print('   - id: ${tag.id}, x: ${tag.x}, y: ${tag.y}, url: ${tag.url}');
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
          mediaType: widget.mediaType,
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

  Widget _buildMediaItem(File file, BoxFit fitMode, int index) {
    final tagsForThisImage = _tags.where((tag) => tag.id.contains('_$index')).toList();

    if (_isVideo) {
      return _buildVideoItem(file, fitMode, tagsForThisImage);
    } else {
      return _buildImageItem(file, fitMode, tagsForThisImage);
    }
  }

  // ============================================================
  // 🔥 ВИДЕО - ПРИБЛИЖАЕТ КАК НА ФОТО
  // ============================================================
  Widget _buildVideoItem(File file, BoxFit fitMode, List<PostTag> tagsForThisImage) {
    if (!_isVideoInitialized || _videoController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Loading video...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    final isFullScreen = fitMode == BoxFit.cover;

    return GestureDetector(
      onTap: _toggleVideoPlayback,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 🔥 ВИДЕО - ПРИБЛИЖЕНИЕ (КАК НА ФОТО)
            Center(
              child: isFullScreen
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController!.value.size.width,
                          height: _videoController!.value.size.height,
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                    )
                  : AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
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
            
            Center(
              child: AnimatedOpacity(
                opacity: _isVideoPlaying ? 0.0 : 0.7,
                duration: const Duration(milliseconds: 300),
                child: GestureDetector(
                  onTap: _toggleVideoPlayback,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white.withOpacity(0.6),
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageItem(File file, BoxFit fitMode, List<PostTag> tagsForThisImage) {
    final isFullScreen = fitMode == BoxFit.cover;

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
          // Основной контент
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
                
                return _buildMediaItem(file, currentFit, index);
              },
            ),
          ),

          // Верхняя панель - стрелка + Next
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 8,
                right: 16,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Стрелка назад
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  
                  // Кнопка Next (без овала)
                  GestureDetector(
                    onTap: _navigateToCaption,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Next',
                            style: TextStyle(
                              color: _tags.isNotEmpty ? Colors.blue : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_tags.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${_tags.length}',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Правая панель - иконки столбиком (БЕЗ КРУЖКОВ)
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Auto / Full
                _buildRightIcon(
                  icon: (_fitModeForIndex[_currentIndex] ?? BoxFit.contain) == BoxFit.contain
                      ? Icons.aspect_ratio
                      : Icons.fullscreen,
                  label: (_fitModeForIndex[_currentIndex] ?? BoxFit.contain) == BoxFit.contain
                      ? 'Auto'
                      : 'Full',
                  onTap: _toggleFitMode,
                ),
                
                const SizedBox(height: 20),
                
                // Add Link
                _buildRightIcon(
                  icon: Icons.link,
                  label: 'Link',
                  onTap: () => _onImageTap(0.5, 0.5),
                ),
                
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildRightIcon(
                    icon: Icons.local_offer,
                    label: '${_tags.length}',
                    onTap: () {},
                  ),
                ],
              ],
            ),
          ),

          // Индикаторы карусели
          if (widget.selectedFiles.length > 1 && !_isVideo)
            Positioned(
              bottom: 70,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      widget.selectedFiles.length,
                      (index) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentIndex == index 
                              ? Colors.white 
                              : Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Иконка справа (БЕЗ КРУЖКА)
  Widget _buildRightIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}