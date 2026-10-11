import 'package:flutter/material.dart';

/// Presents a dialog overlay with polished Figma-style entry/exit animations:
/// - Smooth backdrop fade to 70% dark scrim (Figma `rgba(0, 0, 0, 0.7)`).
/// - Modal card fade, subtle vertical slide, and ease-out cubic scale.
Future<T?> showBuckOverlayDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0xB3000000), // 70% black (Figma fill_f5d51dc8)
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04), // subtle 4% upward glide
            end: Offset.zero,
          ).animate(curve),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curve),
            child: child,
          ),
        ),
      );
    },
  );
}
