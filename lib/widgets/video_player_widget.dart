// lib/widgets/video_player_widget.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import '../controllers/post_controller.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool showControls;
  final bool isVisible;
  final String? thumbnailUrl;
  final BoxFit fit;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.showControls = true,
    this.isVisible = true,
    this.thumbnailUrl,
    this.fit = BoxFit.cover,
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
  bool _isLoading = true;

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
      _isLoading = true;
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
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      // 1. Инициализируем плеер
      await _controller!.initialize();
      await _controller!.setLooping(true);

      if (!mounted) return;

      // 2. Ставим на автовопроизведение только если экран виден
      if (widget.isVisible) {
        await _controller!.play();
        _isPlaying = true;
      } else {
        _isPlaying = false;
      }

      // 3. Мгновенно обновляем состояние виджета (видео уже рисует 1-й кадр)
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });

      // 4. Мягко убираем тамбнейл без искусственных пауза-задержек
      if (_showThumbnail) {
        setState(() {
          _thumbnailOpacity = 0.0;
        });
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          setState(() {
            _showThumbnail = false;
          });
        }
      }
    } catch (e) {
      print('❌ [VIDEO] Error: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _isLoading = false;
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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasThumbnail =
        widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty;
    final isPreloaded =
        Get.find<PostController>().isVideoPreloaded(widget.videoUrl);

    return GestureDetector(
      onTap: _togglePlayback,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            // ✅ ВИДЕО (Плеер снизу, готов сразу)
            if (_isInitialized && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),

            // ✅ ТАМБНЕЙЛ (Поверх видео, плавно исчезает)
            if (hasThumbnail && _showThumbnail)
              AnimatedOpacity(
                opacity: _thumbnailOpacity,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: CachedNetworkImage(
                  imageUrl: widget.thumbnailUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.black),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.grey, size: 40),
                    ),
                  ),
                ),
              ),

            // ✅ ЛОАДЕР
            if (_isLoading && !hasThumbnail && !isPreloaded)
              Container(
                color: Colors.black54,
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

            // ✅ ИКОНКА PLAY
            if (!_isPlaying &&
                widget.showControls &&
                !_wasStoppedByScroll &&
                _isInitialized)
              AnimatedOpacity(
                opacity: 0.85,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.grey.shade400.withOpacity(0.85),
                  size: 110,
                ),
              ),
          ],
        ),
      ),
    );
  }
}