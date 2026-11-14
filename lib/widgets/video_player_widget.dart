// lib/widgets/video_player_widget.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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
  bool _isPausedByUser = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeAndReset().then((_) {
        _initVideo();
      });
      return;
    }

    if (oldWidget.isVisible != widget.isVisible) {
      _handleVisibilityChange(widget.isVisible);
    }
  }

  Future<void> _disposeAndReset() async {
    _isInitialized = false;
    _isPlaying = false;

    if (_controller != null) {
      final controllerToDispose = _controller;
      _controller = null;

      try {
        await controllerToDispose?.pause();
        await controllerToDispose?.dispose();
        print('🧹 [VIDEO] Released MediaCodec buffers successfully');
      } catch (e) {
        print('⚠️ [VIDEO] Error releasing controller: $e');
      }
    }
  }

  void _handleVisibilityChange(bool isVisible) {
    if (_controller == null || !_isInitialized) return;

    if (isVisible) {
      // ⚡ Пост вернулся на экран — играем, если пользователь не ставил паузу
      if (!_isPausedByUser) {
        _controller!.play();
        if (mounted) setState(() => _isPlaying = true);
      }
    } else {
      // ⏸️ Пост ушёл — пауза и сброс в начало. _isPausedByUser НЕ трогаем!
      _controller!.pause();
      _controller!.seekTo(Duration.zero);
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _initVideo() async {
    try {
      print('📹 [VIDEO] Starting initialization: ${widget.videoUrl}');

      VideoPlayerController controller;

      if (widget.videoUrl.startsWith('http')) {
        final fileInfo = await DefaultCacheManager().getFileFromCache(widget.videoUrl);

        if (fileInfo != null) {
          print('⚡ [VIDEO] Found in cache! Loading from disk.');
          controller = VideoPlayerController.file(
            fileInfo.file,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        } else {
          print('🌐 [VIDEO] Streaming over HTTP...');
          controller = VideoPlayerController.networkUrl(
            Uri.parse(widget.videoUrl),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );

          DefaultCacheManager().downloadFile(widget.videoUrl).catchError((e) {
            print('⚠️ [VIDEO] Background cache download failed: $e');
            return fileInfo!;
          });
        }
      } else {
        controller = VideoPlayerController.file(
          File(widget.videoUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      }

      _controller = controller;
      await controller.initialize();

      if (!mounted) return;

      controller.setVolume(1.0);
      controller.setLooping(true);

      if (widget.isVisible && !_isPausedByUser) {
        await controller.play();
        _isPlaying = true;
      } else {
        _isPlaying = false;
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      print('✅ [VIDEO] Initialized successfully');
    } catch (e) {
      print('❌ [VIDEO] Error initializing controller: $e');
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
        _isPausedByUser = true; // 🔥 Пользователь сам поставил паузу
      });
    } else {
      _controller!.play();
      setState(() {
        _isPlaying = true;
        _isPausedByUser = false; // 🔥 Пользователь снял паузу
      });
    }
  }

  @override
  void dispose() {
    print('🗑️ [VIDEO] Disposing widget state');
    _disposeAndReset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayback,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            // 1. Превью / Обложка
            if (widget.thumbnailUrl != null)
              Image.network(
                widget.thumbnailUrl!,
                fit: widget.fit,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),

            // 2. Видеоплеер
            if (_isInitialized && _controller != null)
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

            // 3. Индикатор загрузки (крутится, пока не инициализировано)
            if (!_isInitialized)
              const Center(
                child: SpinKitThreeBounce(
                  color: Colors.white70,
                  size: 26.0,
                ),
              ),

            // 4. 🔥 ИКОНКА PLAY — ТОЛЬКО если пользователь сам нажал паузу!
            // Если видео просто свёрнуто (скролл), _isPausedByUser == false,
            // значит иконки не будет — только стоп-кадр.
            if (_isInitialized && _isPausedByUser && widget.showControls)
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