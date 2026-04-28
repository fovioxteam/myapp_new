// lib/widgets/infinite_scroll_loader.dart

import 'package:flutter/material.dart';

class InfiniteScrollLoader extends StatelessWidget {
  final bool hasMore;
  final bool isLoading;
  final VoidCallback onLoadMore;

  const InfiniteScrollLoader({
    super.key,
    required this.hasMore,
    required this.isLoading,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasMore) return const SizedBox.shrink();
    
    // Запускаем загрузку при появлении виджета
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isLoading) {
        onLoadMore();
      }
    });

    return Container(
      height: 60,
      color: Colors.transparent,
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}