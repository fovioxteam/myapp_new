// lib/widgets/search_grid_thumbnail.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchGridThumbnail extends StatefulWidget {
  final String imageUrl;
  final String postId;
  final VoidCallback onTap;

  const SearchGridThumbnail({
    super.key,
    required this.imageUrl,
    required this.postId,
    required this.onTap,
  });

  @override
  State<SearchGridThumbnail> createState() => _SearchGridThumbnailState();
}

class _SearchGridThumbnailState extends State<SearchGridThumbnail> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  
  // Кэшируем изображение в памяти виджета
  ImageProvider? _cachedImage;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _preloadImage();
  }

  void _preloadImage() {
    if (widget.imageUrl.isEmpty) {
      _isLoading = false;
      return;
    }
    
    // Предзагружаем изображение
    final provider = CachedNetworkImageProvider(
      widget.imageUrl,
      cacheKey: 'search_thumb_${widget.postId}',
      maxWidth: 300,
      maxHeight: 300,
    );
    
    provider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener(
        (info, sync) {
          if (mounted) {
            setState(() {
              _cachedImage = provider;
              _isLoading = false;
            });
          }
        },
        onError: (error, stackTrace) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: Colors.grey[100],
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 30),
      );
    }
    
    if (_isLoading) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
        ),
      );
    }
    
    if (_hasError || _cachedImage == null) {
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.error, color: Colors.grey, size: 30),
      );
    }
    
    return Image(
      image: _cachedImage!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true, // <- КЛЮЧЕВОЙ ПАРАМЕТР! Не перезагружает при rebuild
    );
  }
}