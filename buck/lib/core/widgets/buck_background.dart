import 'package:flutter/material.dart';

class BuckBackground extends StatelessWidget {
  final Widget child;
  final bool useSafeArea;

  const BuckBackground({
    super.key,
    required this.child,
    this.useSafeArea = false,
  });

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
    return Container(
      color: const Color(0xFF2B1309),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Preserve the natural dark-brown upper region of background_waves.png
          // so it transitions smoothly into the #2B1309 browser bar chrome.
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_waves.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.45),
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
                        Color(0xFF2B1309),
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
          // Smooth multi-stop top and bottom background feathers matching Safari's #2B1309 chrome
          _edgeFeather(isTop: true, height: 180, multiStop: true),
          _edgeFeather(isTop: false, height: 220, multiStop: true),
          // Child content
          if (useSafeArea) SafeArea(child: child) else child,
          // Subtle scroll-edge fades so scrolling content never shears abruptly
          _edgeFeather(isTop: true, height: 12),
          _edgeFeather(isTop: false, height: 12),
        ],
      ),
    );
  }

  Widget _edgeFeather({
    required bool isTop,
    required double height,
    bool multiStop = false,
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
              colors: multiStop
                  ? _featherColors
                  : const [
                      Color(0xFF2B1309),
                      Color(0x002B1309),
                    ],
              stops: multiStop ? _featherStops : const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
