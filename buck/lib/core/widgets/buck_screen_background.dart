import 'package:flutter/material.dart';

/// In-app screen backdrop rendered from the pre-blurred Figma wave asset.
///
/// Uses smooth multi-stop #2B1309 feathers at the top and bottom edges so
/// in-app screens transition seamlessly into system status bars and Safari's
/// floating chrome with zero unblurred SVG filter edges.
class BuckScreenBackground extends StatelessWidget {
  const BuckScreenBackground({super.key});

  static const List<Color> _featherColors = [
    Color(0xFF2B1309),
    Color(0xC42B1309),
    Color(0x732B1309),
    Color(0x262B1309),
    Color(0x002B1309),
  ];

  static const List<double> _featherStops = [0.0, 0.22, 0.48, 0.75, 1.0];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF2B1309),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_waves.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.35),
              errorBuilder: (context, error, stackTrace) {
                return const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.8, -0.6),
                      radius: 1.2,
                      colors: [
                        Color(0xFF8C3E14),
                        Color(0xFF351208),
                        Color(0xFF2B1309),
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
          // Subtle dark espresso veil so glass cards maintain crisp contrast
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Color(0x33140703)),
            ),
          ),
          // Smooth multi-stop top and bottom feathers matching Safari's #2B1309 chrome
          _edgeFeather(isTop: true, height: 180),
          _edgeFeather(isTop: false, height: 240),
        ],
      ),
    );
  }

  Widget _edgeFeather({required bool isTop, required double height}) {
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
              colors: _featherColors,
              stops: _featherStops,
            ),
          ),
        ),
      ),
    );
  }
}
