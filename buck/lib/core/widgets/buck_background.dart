import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BuckBackground extends StatelessWidget {
  final Widget child;
  final bool useSafeArea;

  const BuckBackground({
    super.key,
    required this.child,
    this.useSafeArea = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navBarBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image / gradient waves from Figma
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_waves.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback custom radial/linear gradient if asset cannot load
                return Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.8, -0.6),
                      radius: 1.2,
                      colors: [
                        Color(0xFF8C3E14),
                        Color(0xFF351208),
                        AppColors.navBarBg,
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
          // Blend the top edge seamlessly into the browser/status-bar chrome (#100B09)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 88,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.navBarBg,
                      AppColors.navBarBg.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Soften bottom edge transition above gesture indicator / Safari capsule
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 72,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.navBarBg.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Child content
          if (useSafeArea) SafeArea(child: child) else child,
        ],
      ),
    );
  }
}
