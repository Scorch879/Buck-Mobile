import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Five destinations of the Figma "Footer / Mobile" component (2156:4311).
enum BuckTab { wallet, expenses, home, stats, goals }

/// Floating bottom navigation bar.
///
/// Features a sliding raised cream circle indicator that glides ("pushes in")
/// smoothly between tabs without fading, while all tab icons remain firmly
/// in place with seamless color transitions.
class BuckFooterNav extends StatelessWidget {
  final BuckTab activeTab;
  final ValueChanged<BuckTab> onTabSelected;

  const BuckFooterNav({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
  });

  /// Total footer height in the Figma frame (bar + raised tab overflow).
  static const double height = 98;

  static const double _frameWidth = 440;
  static const double _barWidth = 408;
  static const double _barHeight = 65;
  static const double _barLeft = (_frameWidth - _barWidth) / 2;
  static const double _barTop = (height - _barHeight) / 2 + 0.5;

  static const double _circleDiameter = 72;
  static const double _circleTop = (height - _circleDiameter) / 2;

  static const Map<BuckTab, _TabMeta> _tabMetas = {
    BuckTab.wallet: _TabMeta(
      asset: 'assets/icons/footer_icon_wallet.svg',
      width: 30,
      height: 30,
      centerX: 64,
    ),
    BuckTab.expenses: _TabMeta(
      asset: 'assets/icons/footer_icon_expenses.svg',
      width: 30,
      height: 28,
      centerX: 142,
    ),
    BuckTab.home: _TabMeta(
      asset: 'assets/icons/footer_icon_home.svg',
      width: 32,
      height: 32,
      centerX: 220,
    ),
    BuckTab.stats: _TabMeta(
      asset: 'assets/icons/footer_icon_stats.svg',
      width: 30,
      height: 30,
      centerX: 298,
    ),
    BuckTab.goals: _TabMeta(
      asset: 'assets/icons/footer_icon_goals.svg',
      width: 30,
      height: 30,
      centerX: 376,
    ),
  };

  static bool hasDesign(BuckTab tab) =>
      tab == BuckTab.home || tab == BuckTab.expenses || tab == BuckTab.goals;

  // Tap zone boundaries (x within the 440 frame), split at the midpoints
  // between icon centres in the Figma vector.
  static const List<double> _zoneEdges = [0, 101, 180, 254, 334, _frameWidth];

  @override
  Widget build(BuildContext context) {
    final activeMeta = _tabMetas[activeTab] ?? _tabMetas[BuckTab.home]!;
    final raisedLeft = activeMeta.centerX - (_circleDiameter / 2);

    return SizedBox(
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: _frameWidth,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Navigation Bar Pill Container
              Positioned(
                left: _barLeft,
                top: _barTop,
                width: _barWidth,
                height: _barHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.navBarBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.navBarBorder, width: 1),
                  ),
                ),
              ),

              // 2. Raised Cream Ellipse (Smoothly translates / pushed in across tabs)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: raisedLeft,
                top: _circleTop,
                width: _circleDiameter,
                height: _circleDiameter,
                child: Container(
                  width: _circleDiameter,
                  height: _circleDiameter,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.navRaisedSurface,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navRaisedGlow,
                        blurRadius: 18,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Persistent Navigation Icons (Fixed in place, no fade in / out)
              for (final entry in _tabMetas.entries)
                Positioned(
                  left: entry.value.centerX - (entry.value.width / 2),
                  top: (height - entry.value.height) / 2,
                  width: entry.value.width,
                  height: entry.value.height,
                  child: IgnorePointer(
                    child: _TabIconWidget(
                      meta: entry.value,
                      isActive: entry.key == activeTab,
                    ),
                  ),
                ),

              // 4. Tap Zones
              for (var i = 0; i < BuckTab.values.length; i++)
                Positioned(
                  left: _zoneEdges[i],
                  width: _zoneEdges[i + 1] - _zoneEdges[i],
                  top: 0,
                  bottom: 0,
                  child: Semantics(
                    button: true,
                    selected: BuckTab.values[i] == activeTab,
                    label: _labels[BuckTab.values[i]],
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTabSelected(BuckTab.values[i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const Map<BuckTab, String> _labels = {
    BuckTab.wallet: 'Wallet',
    BuckTab.expenses: 'Expenses',
    BuckTab.home: 'Home',
    BuckTab.stats: 'Stats',
    BuckTab.goals: 'Goals',
  };
}

class _TabMeta {
  final String asset;
  final double width;
  final double height;
  final double centerX;

  const _TabMeta({
    required this.asset,
    required this.width,
    required this.height,
    required this.centerX,
  });
}

class _TabIconWidget extends StatelessWidget {
  final _TabMeta meta;
  final bool isActive;

  const _TabIconWidget({
    required this.meta,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      tween: ColorTween(
        end: isActive ? AppColors.navBarIconActive : AppColors.navBarIcon,
      ),
      builder: (context, color, _) {
        return AnimatedScale(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          scale: isActive ? 1.06 : 1.0,
          child: SvgPicture.asset(
            meta.asset,
            width: meta.width,
            height: meta.height,
            colorFilter: ColorFilter.mode(
              color ?? AppColors.navBarIcon,
              BlendMode.srcIn,
            ),
          ),
        );
      },
    );
  }
}
