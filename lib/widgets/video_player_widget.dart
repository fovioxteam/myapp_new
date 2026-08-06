import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool showControls;
  final bool isVisible;
  final String? thumbnailUrl;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.showControls = true,
    this.isVisible = true,
    this.thumbnailUrl,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _wasVisible = true;
  bool _wasStoppedByScroll = false;
  bool _isPausedByUser = false;
  
  bool _showThumbnail = true;
  double _thumbnailOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _wasVisible = widget.isVisible;
    _initVideo();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.isVisible != widget.isVisible) {
      _handleVisibilityChange(widget.isVisible);
    }
    
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _showThumbnail = true;
      _thumbnailOpacity = 1.0;
      _initVideo();
    }
  }

  void _handleVisibilityChange(bool isVisible) {
    if (_controller == null || !_isInitialized) return;
    
    if (isVisible && !_wasVisible) {
      if (!_isPausedByUser) {
        _controller!.play();
        setState(() {
          _isPlaying = true;
          _wasStoppedByScroll = false;
        });
      }
    } else if (!isVisible && _wasVisible) {
      if (_isPlaying) {
        _controller!.pause();
        _controller!.seekTo(Duration.zero);
        setState(() {
          _isPlaying = false;
          _wasStoppedByScroll = true;
        });
      }
    }
    
    _wasVisible = isVisible;
  }

  Future<void> _initVideo() async {
    try {
      print('📹 [VIDEO] Loading: ${widget.videoUrl}');
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
        ),
      );
      
      await _controller!.initialize();
      
      if (widget.isVisible) {
        await _controller!.play();
        setState(() => _isPlaying = true);
      }
      
      await _controller!.setLooping(true);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        
        // Плавное исчезновение тамбнейла
        if (_showThumbnail) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            setState(() {
              _thumbnailOpacity = 0.0;
            });
            await Future.delayed(const Duration(milliseconds: 400));
            if (mounted) {
              setState(() {
                _showThumbnail = false;
              });
            }
          }
        }
        
        print('✅ [VIDEO] Loaded and ${widget.isVisible ? 'playing' : 'paused'}');
      }
    } catch (e) {
      print('❌ [VIDEO] Error: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  void _togglePlayback() {
    if (_controller == null || !_isInitialized) return;
    
    if (_isPlaying) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
        _isPausedByUser = true;
        _wasStoppedByScroll = false;
      });
    } else {
      _controller!.play();
      setState(() {
        _isPlaying = true;
        _isPausedByUser = false;
        _wasStoppedByScroll = false;
      });
    }
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.pause();
      _controller!.dispose();
      _controller = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasThumbnail = widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty;

    return GestureDetector(
      onTap: _togglePlayback,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🔥 ВИДЕО (КАК БЫЛО - С AspectRatio)
            if (_isInitialized && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            
            // 🔥 РАЗМЫТЫЙ ТАМБНЕЙЛ ПОВЕРХ ВИДЕО
            if (hasThumbnail && _showThumbnail)
              AnimatedOpacity(
                opacity: _thumbnailOpacity,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                child: AspectRatio(
                  aspectRatio: _controller != null && _controller!.value.isInitialized
                      ? _controller!.value.aspectRatio
                      : 9 / 16,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: 20.0,
                      sigmaY: 20.0,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: widget.thumbnailUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[900],
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            
            // 🔥 ЛОАДЕР (ТОЛЬКО ЕСЛИ НЕТ ТАМБНЕЙЛА)
            if (!_isInitialized && !hasThumbnail)
              Container(
                color: Colors.black,
                child: const Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
            
            // 🔥 ИКОНКА PLAY
            if (!_isPlaying && widget.showControls && !_wasStoppedByScroll && _isInitialized)
              AnimatedOpacity(
                opacity: 0.85,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.grey.shade400.withOpacity(0.85),
                  size: 110,
                  weight: 900.0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}