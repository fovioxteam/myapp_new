// lib/widgets/web_image_loader.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class WebImageLoader extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final String? placeholderAsset;
  final IconData? errorIcon;

  const WebImageLoader({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.color,
    this.placeholderAsset,
    this.errorIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      // Для нативных платформ используем стандартный Image.network
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        color: color,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading image: $error');
          return _buildErrorWidget();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
      );
    }

    // Для веба используем специальный подход
    return _buildWebImage();
  }

  Widget _buildWebImage() {
    // Пробуем несколько вариантов загрузки
    return Image.network(
      _getProxiedUrl(),
      width: width,
      height: height,
      fit: fit,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        print('❌ Error loading image with proxy: $error');
        // Пробуем без прокси
        return Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          color: color,
          errorBuilder: (context, error2, stackTrace2) {
            print('❌ Error loading image without proxy: $error2');
            return _buildErrorWidget();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildPlaceholder();
          },
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildPlaceholder();
      },
    );
  }

  String _getProxiedUrl() {
    // Используем разные прокси для разных случаев
    if (imageUrl.contains('firebasestorage.googleapis.com')) {
      // Для Firebase Storage добавляем alt=media
      if (!imageUrl.contains('alt=')) {
        return '$imageUrl${imageUrl.contains('?') ? '&' : '?'}alt=media';
      }
      return imageUrl;
    }
    
    // Для тестовых изображений используем picsum напрямую (они обычно работают)
    if (imageUrl.contains('picsum.photos')) {
      return imageUrl;
    }
    
    // Для остальных случаев используем CORS прокси
    return 'https://cors-anywhere.herokuapp.com/$imageUrl';
  }

  Widget _buildPlaceholder() {
    if (placeholderAsset != null) {
      return Image.asset(
        placeholderAsset!,
        width: width,
        height: height,
        fit: fit,
      );
    }
    
    return Container(
      width: width,
      height: height,
      color: Colors.grey[900],
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.grey,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (errorIcon != null) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[900],
        child: Center(
          child: Icon(
            errorIcon,
            color: Colors.grey[600],
            size: 30,
          ),
        ),
      );
    }
    
    return Container(
      width: width,
      height: height,
      color: Colors.grey[900],
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 30,
        ),
      ),
    );
  }
}