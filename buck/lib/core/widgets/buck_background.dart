import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BuckBackground extends StatelessWidget {
  final Widget child;

  const BuckBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
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
                        AppColors.background,
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
          // Child content
          SafeArea(child: child),
        ],
      ),
    );
  }
}
