import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/buck_overlay_dialog.dart';
import '../../data/services/buck_ai_service.dart';

/// Shows an AI-powered personalized savings and execution tip for a specific financial goal.
Future<void> showAiGoalTipDialog({
  required BuildContext context,
  required String goalName,
  required double targetAmount,
  String? goalId,
  BuckAiService? aiService,
}) {
  return showBuckOverlayDialog<void>(
    context: context,
    builder: (ctx) => _GoalTipDialogContent(
      goalName: goalName,
      targetAmount: targetAmount,
      goalId: goalId,
      aiService: aiService ?? BuckAiService.instance,
    ),
  );
}

class _GoalTipDialogContent extends StatefulWidget {
  final String goalName;
  final double targetAmount;
  final String? goalId;
  final BuckAiService aiService;

  const _GoalTipDialogContent({
    required this.goalName,
    required this.targetAmount,
    this.goalId,
    required this.aiService,
  });

  @override
  State<_GoalTipDialogContent> createState() => _GoalTipDialogContentState();
}

class _GoalTipDialogContentState extends State<_GoalTipDialogContent> {
  bool _loading = true;
  String? _tip;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTip();
  }

  Future<void> _fetchTip() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tip = await widget.aiService.getGoalTip(
        goalId: widget.goalId,
        goalName: widget.goalName,
        targetAmount: widget.targetAmount,
      );
      if (mounted) {
        setState(() {
          _tip = tip ??
              'Set aside a consistent monthly amount into your designated savings wallet to stay on track.';
          _loading = false;
        });
      }
    } catch (e) {
      final friendly = e is BuckAiException
          ? e.message
          : 'Unable to get AI tip right now.';
      if (mounted) {
        setState(() {
          _error = friendly;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF19100B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassCardBorder, width: 1),
            boxShadow: const [
              BoxShadow(color: AppColors.glassCardGlow, blurRadius: 28),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gradientOrangeStart,
                          AppColors.gradientOrangeEnd,
                        ],
                      ),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI GOAL STRATEGY',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.textAccent,
                          ),
                        ),
                        Text(
                          widget.goalName,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primaryOrange),
                  ),
                ),
              ] else if (_error != null) ...[
                Text(
                  _error!,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _fetchTip,
                  child: const Text('Try Again', style: TextStyle(color: AppColors.primaryOrange)),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF231610),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    _tip!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Got It',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
