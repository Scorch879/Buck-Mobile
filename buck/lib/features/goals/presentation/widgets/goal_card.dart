import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/buck_glass_card.dart';
import '../../data/goal_model.dart';

class GoalCard extends StatelessWidget {
  final GoalItem goal;
  final ValueChanged<GoalItem> onAllocate;

  const GoalCard({
    super.key,
    required this.goal,
    required this.onAllocate,
  });

  String _formatCurrency(double amount) {
    final integerPart = amount.toInt();
    final buffer = StringBuffer();
    final digits = integerPart.toString();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return '₱$buffer';
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return BuckGlassCard(
      radius: 24,
      glowBlur: 28,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 20,
        vertical: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Row: Icon + Title/Target + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: goal.themeColor.withValues(alpha: 0.15),
                ),
                alignment: Alignment.center,
                child: Icon(goal.icon, size: 20, color: goal.themeColor),
              ),
              const SizedBox(width: 10),
              // Title & Target Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFFF7EE),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      goal.targetDate,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFC6B5AB),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status Badge
              _statusBadge(),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Amount Row: Current Amount vs Target Amount
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _formatCurrency(goal.currentAmount),
                  style: GoogleFonts.manrope(
                    fontSize: isCompact ? 21 : 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'of ${_formatCurrency(goal.targetAmount)}',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFC6B5AB),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. Progress Bar Track
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              width: double.infinity,
              color: const Color(0xFF4A2D22),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: goal.progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: goal.gradientColors,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // 4. Progress Labels / Completion Text
          if (goal.status == GoalStatus.completed)
            Text(
              '🎉 100% — Goal Achieved!',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: goal.themeColor,
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 340,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${goal.percentage.toStringAsFixed(1)}% saved',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: goal.themeColor,
                      ),
                    ),
                    Text(
                      '${_formatCurrency(goal.remaining)} remaining',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFC6B5AB),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Action Button (Only shown if not completed)
          if (goal.status != GoalStatus.completed) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 36,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1D110C),
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => onAllocate(goal),
                child: Text(
                  'Allocate Funds from Wallet →',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1D110C),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge() {
    switch (goal.status) {
      case GoalStatus.onTrack:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2F9E7C).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'On Track',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF36C49A),
            ),
          ),
        );
      case GoalStatus.completed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: goal.themeColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: 14, color: goal.themeColor),
              const SizedBox(width: 4),
              Text(
                'Completed!',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: goal.themeColor,
                ),
              ),
            ],
          ),
        );
      case GoalStatus.inProgress:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: goal.themeColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'In Progress',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: goal.themeColor,
            ),
          ),
        );
    }
  }
}
