import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/buck_glass_card.dart';

enum QuickAction { scanReceipt, addExpense, addIncome, transfer }

/// Figma "Quick Action Bar" (2242:287).
class QuickActionsCard extends StatelessWidget {
  final ValueChanged<QuickAction> onAction;

  const QuickActionsCard({super.key, required this.onAction});

  static const _actions = [
    (QuickAction.scanReceipt, 'assets/icons/scan.svg', 'Scan Receipt'),
    (QuickAction.addExpense, 'assets/icons/minus_circle.svg', 'Add Expense'),
    (QuickAction.addIncome, 'assets/icons/plus_circle.svg', 'Add Income'),
    (QuickAction.transfer, 'assets/icons/arrow_right_left.svg', 'Transfer'),
  ];

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    return BuckGlassCard(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 20,
        vertical: isCompact ? 16 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              // 4 × 74px actions + 3 × 10px gaps
              constraints: const BoxConstraints(maxWidth: 326),
              child: Row(
                spacing: isCompact ? 6 : 10,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (action, icon, label) in _actions)
                    Expanded(
                      child: _QuickActionButton(
                        icon: icon,
                        label: label,
                        onTap: () => onAction(action),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.actionIconBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _pressed
                        ? AppColors.primaryOrange
                        : AppColors.actionIconBorder,
                    width: 1,
                  ),
                ),
                child: SvgPicture.asset(widget.icon),
              ),
              const SizedBox(height: 8),
              // Scale down (never wrap) when narrow phones squeeze the 74px slot.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _pressed
                        ? AppColors.textAccent
                        : AppColors.textSecondary,
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
