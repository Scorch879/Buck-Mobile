import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// In-app screen backdrop from Figma "Background / Clipped to Screen"
/// (Home Dashboard 2248:240, Expenses 2245:505).
///
/// Shapes are laid out on the 440x956 Figma frame and scaled to cover the
/// device, so proportions match the design on every screen size.
class BuckScreenBackground extends StatelessWidget {
  const BuckScreenBackground({super.key});

  static const double _frameWidth = 440;
  static const double _frameHeight = 956;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.screenGradientTop, AppColors.screenGradientBottom],
        ),
      ),
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: _frameWidth,
            height: _frameHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Background / Bottom Glow — flipped vertically.
                Positioned(
                  left: -11,
                  top: -20,
                  width: 641,
                  height: 799,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(1, -1, 1),
                    child: const _InsetSvg(
                      asset: 'assets/backgrounds/bottom_glow.svg',
                      left: -50,
                      top: -40,
                    ),
                  ),
                ),
                // Background / Top Glow.
                const Positioned(
                  left: -23,
                  top: -180,
                  width: 571,
                  height: 560,
                  child: _InsetSvg(
                    asset: 'assets/backgrounds/top_glow.svg',
                    left: -50,
                    top: -30,
                  ),
                ),
                // Background / Accent Shape — flipped vertically, then rotated 90°.
                Positioned(
                  left: 9,
                  top: 705,
                  width: 601,
                  height: 590,
                  child: OverflowBox(
                    minWidth: 590,
                    maxWidth: 590,
                    minHeight: 601,
                    maxHeight: 601,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationZ(math.pi / 2)
                        ..multiply(Matrix4.diagonal3Values(1, -1, 1)),
                      child: const SizedBox(
                        width: 590,
                        height: 601,
                        child: _InsetSvg(
                          asset: 'assets/backgrounds/accent_shape.svg',
                          left: -50,
                          top: -17,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Places an SVG at its native size, offset by the Figma export bleed.
class _InsetSvg extends StatelessWidget {
  final String asset;
  final double left;
  final double top;

  const _InsetSvg({required this.asset, required this.left, required this.top});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(left: left, top: top, child: SvgPicture.asset(asset)),
      ],
    );
  }
}
