import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../screens/ai_chat_sheet.dart';

/// Floating AI Financial Advisor chat bubble matching the web app's AIChatBubble.
///
/// Features a subtle glowing gradient border and sparkles icon. Tapping opens
/// the streaming AI Advisor chat modal.
class AiFloatingChatBubble extends StatefulWidget {
  final VoidCallback? onTap;

  const AiFloatingChatBubble({super.key, this.onTap});

  @override
  State<AiFloatingChatBubble> createState() => _AiFloatingChatBubbleState();
}

class _AiFloatingChatBubbleState extends State<AiFloatingChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    // In widget tests, avoid infinite repeat loops so tester.pumpAndSettle() can settle cleanly.
    final isTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('Test');
    if (!isTest) {
      _anim.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final glow = _anim.value;
        return GestureDetector(
          onTap: widget.onTap ?? () => showAiChatSheet(context),
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
                  color: AppColors.primaryOrange.withValues(alpha: 0.35 + (0.25 * glow)),
                  blurRadius: 10 + (6 * glow),
                  spreadRadius: 1 + (2 * glow),
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
        );
      },
    );
  }
}
