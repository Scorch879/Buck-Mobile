import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// In-app screen backdrop rendered from the pre-blurred Figma wave asset.
///
/// Adapts between dark espresso (`#2B1309`) and warm cream (`#F6EDE4`) when
/// Light mode is active in Appearance settings.
class BuckScreenBackground extends StatelessWidget {
  const BuckScreenBackground({super.key});

  static const List<Color> _darkFeatherColors = [
    Color(0xFF2B1309),
    Color(0xC42B1309),
    Color(0x732B1309),
    Color(0x262B1309),
    Color(0x002B1309),
  ];

  static const List<Color> _lightFeatherColors = [
    Color(0xFFF6EDE4),
    Color(0xD4F6EDE4),
    Color(0x8CF6EDE4),
    Color(0x38F6EDE4),
    Color(0x00F6EDE4),
  ];

  static const List<double> _featherStops = [0.0, 0.22, 0.48, 0.75, 1.0];

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    final isLight = palette.isLight;

    return ColoredBox(
      color: palette.shellBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_waves.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.35),
              filterQuality: FilterQuality.low,
              opacity: isLight
                  ? const AlwaysStoppedAnimation<double>(0.16)
                  : null,
              errorBuilder: (context, error, stackTrace) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.8, -0.6),
                      radius: 1.2,
                      colors: isLight
                          ? const [
                              Color(0xFFFFD8BA),
                              Color(0xFFF9EAE0),
                              Color(0xFFF6EDE4),
                            ]
                          : const [
                              Color(0xFF8C3E14),
                              Color(0xFF351208),
                              Color(0xFF2B1309),
                            ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: isLight
                    ? const Color(0x40FFF6EE)
                    : const Color(0x33140703),
              ),
            ),
          ),
          _edgeFeather(isTop: true, height: 180, isLight: isLight),
          _edgeFeather(isTop: false, height: 240, isLight: isLight),
        ],
      ),
    );
  }

  Widget _edgeFeather({
    required bool isTop,
    required double height,
    required bool isLight,
  }) {
    return Positioned(
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      left: 0,
      right: 0,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
              end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
              colors: isLight ? _lightFeatherColors : _darkFeatherColors,
              stops: _featherStops,
            ),
          ),
        ),
      ),
    );
  }
}
