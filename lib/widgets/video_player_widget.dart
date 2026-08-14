// lib/widgets/video_player_widget.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

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

  bool _isVideoFrameReady = false;
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
      _disposeController();
      _isInitialized = false;
      _isVideoFrameReady = false;
      _isLoading = true;
      _initVideo();
    }
  }

  void _disposeController() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _controller = null;
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
      print('📹 [VIDEO] Initializing: ${widget.videoUrl}');

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
        ),
      );

      await _controller!.initialize();
      print('✅ [VIDEO] Controller initialized: ${_controller!.value.size}');

      await _controller!.setVolume(1.0);
      await _controller!.setLooping(true);

      _controller!.addListener(_videoListener);

      if (!mounted) return;

      if (widget.isVisible) {
        await _controller!.play();
        _isPlaying = true;
        print('▶️ [VIDEO] Playing');
      } else {
        _isPlaying = false;
        print('⏸️ [VIDEO] Paused');
      }

      setState(() {
        _isInitialized = true;
        _isLoading = false;
        // 💡 Если контроллер уже инициализирован и проигрывается, 
        // сразу взводим флаг готовности, чтобы не ждать срабатывания listener при холодном старте
        if (_controller!.value.isPlaying || _controller!.value.position > Duration.zero) {
          _isVideoFrameReady = true;
        }
      });

    } catch (e) {
      print('❌ [VIDEO] Error initializing controller: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _isLoading = false;
        });
      }
    }
  }

  void _videoListener() {
    if (_controller != null &&
        _controller!.value.isInitialized &&
        !_isVideoFrameReady) {
      // Расширенная проверка: готово ли видео к отображению
      if (_controller!.value.position > Duration.zero || 
          _controller!.value.isPlaying || 
          !_controller!.value.isBuffering) {
        if (mounted) {
          print('🎬 [VIDEO] First frame ready via listener');
          setState(() {
            _isVideoFrameReady = true;
          });
        }
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
    print('🗑️ [VIDEO] Disposing');
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showVideoNow = _isInitialized && _controller != null && _isVideoFrameReady;

    return GestureDetector(
      onTap: _togglePlayback,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            // 1. ВИДЕОПЛЕЕР
            if (showVideoNow)
              Positioned.fill(
                child: FittedBox(
                  fit: widget.fit,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),

            // 2. ЛОАДЕР
            if (_isLoading || !_isVideoFrameReady)
              const Center(
                child: SpinKitThreeBounce(
                  color: Colors.white70,
                  size: 26.0,
                ),
              ),

            // 3. ИКОНКА PLAY
            if (!_isPlaying &&
                widget.showControls &&
                !_wasStoppedByScroll &&
                _isInitialized &&
                _isVideoFrameReady)
              Icon(
                Icons.play_arrow,
                color: Colors.white.withAlpha(216),
                size: 110,
              ),
          ],
        ),
      ),
    );
  }
}