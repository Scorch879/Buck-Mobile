import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../screens/ai_chat_sheet.dart';

/// Floating, draggable AI Financial Advisor chat bubble matching the web app's AIChatBubble.
///
/// Features a glowing gradient border, sparkles icon, and drag-to-reposition support
/// so it never permanently obstructs underlying list items.
class AiFloatingChatBubble extends StatefulWidget {
  final VoidCallback? onTap;

  const AiFloatingChatBubble({super.key, this.onTap});

  @override
  State<AiFloatingChatBubble> createState() => _AiFloatingChatBubbleState();
}

class _AiFloatingChatBubbleState extends State<AiFloatingChatBubble> {
  Offset _dragOffset = Offset.zero;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _dragOffset,
      child: Semantics(
        button: true,
        label: 'Open Buck AI Advisor Chat',
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap ?? () => showAiChatSheet(context),
          onPanUpdate: (details) {
            final screenSize = MediaQuery.sizeOf(context);
            final safePadding = MediaQuery.paddingOf(context);
            const bubbleSize = 52.0;
            final minDx = -(screenSize.width - bubbleSize - 26.0)
                .clamp(0.0, double.infinity);
            const maxDx = 10.0;
            final minDy =
                -(screenSize.height - bubbleSize - safePadding.top - 140.0)
                    .clamp(0.0, double.infinity);
            const maxDy = 60.0;

            setState(() {
              final next = _dragOffset + details.delta;
              _dragOffset = Offset(
                next.dx.clamp(minDx, maxDx),
                next.dy.clamp(minDy, maxDy),
              );
            });
          },
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: 52,
              height: 52,
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
                    color: AppColors.primaryOrange.withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: 2,
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
        ),
      ),
    );
  }
}
