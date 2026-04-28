import 'package:flutter/material.dart';

class ShimmerLoading extends StatelessWidget {
  final Widget child;
  
  const ShimmerLoading({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: child,
    );
  }
}