// lib/widgets/progressive_image.dart

import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

final Uint8List kTransparentImage = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x45, 0x44, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class ProgressiveImage extends StatefulWidget {
  final String thumbnailUrl;
  final String fullUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final bool enableBlur;
  final bool isVisible;
  final int priority;
  
  const ProgressiveImage({
    super.key,
    required this.thumbnailUrl,
    required this.fullUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.enableBlur = true,
    this.isVisible = false,
    this.priority = 2,
  });

  @override
  State<ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends State<ProgressiveImage> {
  bool _isFullLoaded = false;
  bool _isLoadingFull = false;
  bool _useBlur = true;

  @override
  void initState() {
    super.initState();
    _useBlur = widget.enableBlur;
    _scheduleLoad();
  }

  void _scheduleLoad() {
    if (!widget.isVisible) return;
    
    if (widget.priority == 0) {
      _loadFullImage();
    } else if (widget.priority == 1) {
      Future.delayed(const Duration(milliseconds: 50), _loadFullImage);
    } else if (widget.priority == 2) {
      Future.delayed(const Duration(milliseconds: 150), _loadFullImage);
    }
  }

  @override
  void didUpdateWidget(ProgressiveImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isVisible && !_isFullLoaded && !_isLoadingFull) {
      _scheduleLoad();
      _useBlur = false;
    } else if (!widget.isVisible) {
      _useBlur = widget.enableBlur;
    }
  }

  Future<void> _loadFullImage() async {
    if (_isLoadingFull || _isFullLoaded) return;
    
    setState(() => _isLoadingFull = true);
    
    try {
      final completer = Completer<void>();
      final image = NetworkImage(widget.fullUrl);
      
      final stream = image.resolve(ImageConfiguration());
      late ImageStreamListener listener;
      
      listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (error, stackTrace) {
          if (!completer.isCompleted) completer.completeError(error);
        },
      );
      
      stream.addListener(listener);
      await completer.future;
      stream.removeListener(listener);
      
      if (mounted) {
        setState(() => _isFullLoaded = true);
      }
    } catch (e) {
      print('❌ Failed to load full image: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingFull = false);
      }
    }
  }

  void evictIfNeeded() {
    if (_isFullLoaded && mounted) {
      PaintingBinding.instance.imageCache.evict(NetworkImage(widget.fullUrl));
      setState(() {
        _isFullLoaded = false;
        _isLoadingFull = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 🔥 Миниатюра - теперь с чёрным фоном
        if (_useBlur && !_isFullLoaded)
          ClipRRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
              child: Container(
                color: Colors.black.withOpacity(0.3), // 🔥 ЧЁРНЫЙ ФОН
                child: CachedNetworkImage(
                  imageUrl: widget.thumbnailUrl,
                  width: widget.width,
                  height: widget.height,
                  fit: widget.fit,
                  memCacheWidth: widget.width?.toInt(),
                  memCacheHeight: widget.height?.toInt(),
                  placeholder: (context, url) => Container(
                    color: Colors.black, // 🔥 ЧЁРНЫЙ ФОН ВМЕСТО GREY[200]
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.black, // 🔥 ЧЁРНЫЙ ФОН ВМЕСТО GREY[200]
                    child: const Icon(Icons.broken_image, color: Colors.white54),
                  ),
                ),
              ),
            ),
          )
        else
          CachedNetworkImage(
            imageUrl: widget.thumbnailUrl,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            memCacheWidth: widget.width?.toInt(),
            memCacheHeight: widget.height?.toInt(),
            placeholder: (context, url) => Container(
              color: Colors.black, // 🔥 ЧЁРНЫЙ ФОН ВМЕСТО GREY[200]
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.black, // 🔥 ЧЁРНЫЙ ФОН ВМЕСТО GREY[200]
              child: const Icon(Icons.broken_image, color: Colors.white54),
            ),
          ),
        
        // 🔥 Full image
        if (_isFullLoaded)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: 1.0,
            child: Image.network(
              widget.fullUrl,
              fit: widget.fit,
              width: widget.width,
              height: widget.height,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 100),
                  child: child,
                );
              },
              cacheWidth: widget.width?.toInt(),
              cacheHeight: widget.height?.toInt(),
              errorBuilder: (context, error, stackTrace) {
                return CachedNetworkImage(
                  imageUrl: widget.thumbnailUrl,
                  fit: widget.fit,
                );
              },
            ),
          ),
      ],
    );
  }
}