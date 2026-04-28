// lib/screens/post_preview_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'post_caption_screen.dart';
import '../controllers/post_controller.dart';

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    for (int i = 0; i < widget.selectedFiles.length; i++) {
      _fitModeForIndex[i] = BoxFit.cover;
      _transformations[i] = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _toggleFitMode() {
    setState(() {
      final currentFit = _fitModeForIndex[_currentIndex] ?? BoxFit.cover;
      
      if (currentFit == BoxFit.cover) {
        _fitModeForIndex[_currentIndex] = BoxFit.contain;
        print('🔄 [PREVIEW] Mode changed to: AUTO (contain) for index $_currentIndex');
      } else {
        _fitModeForIndex[_currentIndex] = BoxFit.cover;
        _transformations[_currentIndex] = Matrix4.identity();
        _transformationController.value = Matrix4.identity();
        print('🔄 [PREVIEW] Mode changed to: FULL (cover) for index $_currentIndex');
      }
    });
  }

  void _saveTransformation() {
    _transformations[_currentIndex] = _transformationController.value;
  }

  void _resetTransformations() {
    setState(() {
      _transformations[_currentIndex] = Matrix4.identity();
      _transformationController.value = Matrix4.identity();
      _fitModeForIndex[_currentIndex] = BoxFit.cover;
      _isZoomed = false;
      print('🔄 [PREVIEW] Reset transformations for index $_currentIndex');
    });
  }

  void _navigateToCaption() {
    // Собираем массив режимов для ВСЕХ фото
    final List<String> fitModes = [];
    for (int i = 0; i < widget.selectedFiles.length; i++) {
      final fit = _fitModeForIndex[i] ?? BoxFit.cover;
      fitModes.add(fit == BoxFit.contain ? 'contain' : 'cover');
    }
    
    print('🔥🔥🔥 [PREVIEW] ========== SENDING FIT MODES ==========');
    print('🔥🔥🔥 [PREVIEW] Total images: ${widget.selectedFiles.length}');
    print('🔥🔥🔥 [PREVIEW] FitModes array: $fitModes');
    for (int i = 0; i < fitModes.length; i++) {
      print('   - Image $i: ${fitModes[i]}');
    }
    print('🔥🔥🔥 [PREVIEW] ========================================');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostCaptionScreen(
          selectedFiles: widget.selectedFiles,
          fitModes: fitModes,
        ),
      ),
    ).then((_) {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('🔄 Refreshing posts after returning from caption');
        _postController.refreshUserPosts(currentUser.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: kBottomNavigationBarHeight + 50,
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
                print('📄 [PREVIEW] Switched to index: $index, fit mode: ${_fitModeForIndex[index] == BoxFit.contain ? "Auto" : "Full"}');
              },
              itemBuilder: (context, index) {
                final file = widget.selectedFiles[index];
                final currentFit = _fitModeForIndex[index] ?? BoxFit.cover;
                
                return Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 4.0,
                    boundaryMargin: const EdgeInsets.all(0),
                    panEnabled: true,
                    scaleEnabled: true,
                    onInteractionStart: (details) {
                      setState(() {
                        _isZoomed = true;
                      });
                    },
                    onInteractionEnd: (details) {
                      setState(() {
                        _isZoomed = false;
                      });
                      _saveTransformation();
                    },
                    child: Center(
                      child: Image.file(
                        file,
                        fit: currentFit,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              color: _isZoomed ? Colors.black.withOpacity(0.8) : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                  ),
                  const Text(
                    'Preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: _navigateToCaption,
                    child: const Text(
                      'Next',
                      style: TextStyle(
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
            bottom: kBottomNavigationBarHeight + 70,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.grey[700]!,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton(
                      icon: Icons.aspect_ratio,
                      label: 'Auto',
                      isActive: (_fitModeForIndex[_currentIndex] ?? BoxFit.cover) == BoxFit.contain,
                      onTap: _toggleFitMode,
                    ),
                    _buildModeButton(
                      icon: Icons.fullscreen,
                      label: 'Full',
                      isActive: (_fitModeForIndex[_currentIndex] ?? BoxFit.cover) == BoxFit.cover,
                      onTap: _toggleFitMode,
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_isZoomed)
            Positioned(
              bottom: kBottomNavigationBarHeight + 130,
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

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: kBottomNavigationBarHeight + 50,
              color: Colors.black,
            ),
          ),

          if (widget.selectedFiles.length > 1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: kBottomNavigationBarHeight + 50,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
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
                                    color: isSelected ? Colors.blue : Colors.transparent,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
}