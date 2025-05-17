import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainerWidget extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;

  const GlassContainerWidget({
    super.key,
    required this.child,
    this.width = 200,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.01),
            // borderRadius: BorderRadius.circular(20),
            // border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
