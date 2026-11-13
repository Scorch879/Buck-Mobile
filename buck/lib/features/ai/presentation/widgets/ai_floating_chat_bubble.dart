import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../screens/ai_chat_sheet.dart';

/// Floating, draggable AI Financial Advisor chat bubble matching the web app's AIChatBubble.
///
/// Features a glowing gradient border, sparkles icon, smooth drag tracking, and
/// eased snapping to the closest horizontal screen edge on release.
class AiFloatingChatBubble extends StatefulWidget {
  final VoidCallback? onTap;

  /// Distance from the bottom of the screen to the bubble's resting position.
  final double bottomRestOffset;

  const AiFloatingChatBubble({
    super.key,
    this.onTap,
    this.bottomRestOffset = 100.0,
  });

  @override
  State<AiFloatingChatBubble> createState() => _AiFloatingChatBubbleState();
}

class _AiFloatingChatBubbleState extends State<AiFloatingChatBubble>
    with SingleTickerProviderStateMixin {
  static const double _bubbleSize = 52.0;
  static const double _horizontalMargin = 18.0;

  late final AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  Offset? _position;
  bool _pressed = false;
  bool _isDragging = false;
  bool _snappedLeft = false;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    )..addListener(() {
        final anim = _snapAnimation;
        if (anim != null) {
          setState(() {
            _position = anim.value;
          });
        }
      });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  ({double minX, double maxX, double minY, double maxY}) _computeBounds(
    Size areaSize,
    EdgeInsets safePadding,
  ) {
    final minX = _horizontalMargin;
    final maxX = (areaSize.width - _bubbleSize - _horizontalMargin)
        .clamp(minX, double.infinity);
    final minY = (safePadding.top + 96.0)
        .clamp(0.0, (areaSize.height - _bubbleSize).clamp(0.0, double.infinity));
    final maxY = (areaSize.height - widget.bottomRestOffset - _bubbleSize)
        .clamp(minY, double.infinity);

    return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  void _animateTo(Offset target) {
    final start = _position ?? target;
    _snapAnimation = Tween<Offset>(
      begin: start,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _snapController,
        curve: Curves.easeOutCubic,
      ),
    );
    _snapController.forward(from: 0.0);
  }

  void _snapToClosestEdge(
    ({double minX, double maxX, double minY, double maxY}) bounds, {
    double velocityDx = 0.0,
  }) {
    final current = _position ?? Offset(bounds.maxX, bounds.maxY);
    final midX = (bounds.minX + bounds.maxX) / 2;
    // Project slightly along release velocity so quick flicks cross the midline naturally.
    final projectedX = current.dx + velocityDx * 0.08;
    final snapLeft = projectedX <= midX;

    _snappedLeft = snapLeft;
    final targetX = snapLeft ? bounds.minX : bounds.maxX;
    final targetY = current.dy.clamp(bounds.minY, bounds.maxY);

    _animateTo(Offset(targetX, targetY));
  }

  Widget _buildBubble() {
    return Semantics(
      button: true,
      label: 'Open Buck AI Advisor Chat',
      child: AnimatedScale(
        scale: _isDragging ? 1.07 : (_pressed ? 0.92 : 1.0),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          width: _bubbleSize,
          height: _bubbleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                AppColors.gradientOrangeStart,
                AppColors.gradientOrangeEnd,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withValues(
                  alpha: _isDragging ? 0.65 : 0.45,
                ),
                blurRadius: _isDragging ? 18 : 14,
                spreadRadius: _isDragging ? 3 : 2,
              ),
            ],
            border: Border.all(
              color: const Color(0xFFFFD4B2),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            'assets/icons/sparkles.svg',
            width: 24,
            height: 24,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasArea = constraints.hasBoundedWidth &&
            constraints.hasBoundedHeight &&
            constraints.maxWidth > _bubbleSize + (_horizontalMargin * 2);

        if (!hasArea) {
          return GestureDetector(
            onTap: widget.onTap ?? () => showAiChatSheet(context),
            child: _buildBubble(),
          );
        }

        final bounds = _computeBounds(
          Size(constraints.maxWidth, constraints.maxHeight),
          safePadding,
        );

        final currentPos = _position;
        final Offset effectivePos;
        if (currentPos == null) {
          effectivePos = Offset(bounds.maxX, bounds.maxY);
        } else if (_isDragging || _snapController.isAnimating) {
          effectivePos = currentPos;
        } else {
          effectivePos = Offset(
            _snappedLeft ? bounds.minX : bounds.maxX,
            currentPos.dy.clamp(bounds.minY, bounds.maxY),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: effectivePos.dx,
              top: effectivePos.dy,
              child: GestureDetector(
                onTapDown: (_) => setState(() => _pressed = true),
                onTapCancel: () => setState(() => _pressed = false),
                onTapUp: (_) => setState(() => _pressed = false),
                onTap: widget.onTap ?? () => showAiChatSheet(context),
                onPanStart: (_) {
                  _snapController.stop();
                  setState(() {
                    _pressed = false;
                    _isDragging = true;
                    _position = effectivePos;
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    final next = (_position ?? effectivePos) + details.delta;
                    _position = Offset(
                      next.dx.clamp(bounds.minX - 8.0, bounds.maxX + 8.0),
                      next.dy.clamp(bounds.minY - 8.0, bounds.maxY + 8.0),
                    );
                  });
                },
                onPanEnd: (details) {
                  setState(() => _isDragging = false);
                  _snapToClosestEdge(
                    bounds,
                    velocityDx: details.velocity.pixelsPerSecond.dx,
                  );
                },
                onPanCancel: () {
                  if (_isDragging) {
                    setState(() => _isDragging = false);
                    _snapToClosestEdge(bounds);
                  }
                },
                child: _buildBubble(),
              ),
            ),
          ],
        );
      },
    );
  }
}
