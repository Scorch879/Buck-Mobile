import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../allocate_funds_dialog.dart';
import '../create_goal_dialog.dart';
import '../../data/goal_model.dart';
import '../goals_controller.dart';
import '../widgets/goal_card.dart';

/// Figma "Screen / Goals" (#2402:1940) — Financial Goals screen with dynamic non-static values.
class GoalsScreen extends StatelessWidget {
  final GoalsController controller;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onAction;
  final String? activeWalletId;
  final EdgeInsets bottomInset;

  const GoalsScreen({
    super.key,
    required this.controller,
    required this.onRefresh,
    required this.onAction,
    this.activeWalletId,
    this.bottomInset = EdgeInsets.zero,
  });

  Future<void> _handleCreateGoal(BuildContext context) async {
    final result = await showCreateGoalDialog(context);
    if (result != null) {
      await controller.addGoal(
        title: result.title,
        targetAmount: result.targetAmount,
        initialAmount: result.initialAmount,
        targetDate: result.targetDate,
        icon: result.icon,
        themeColor: result.themeColor,
        gradientColors: result.gradientColors,
      );
      onAction("Goal '${result.title}' created successfully!");
    }
  }

  Future<void> _handleAllocateFunds(BuildContext context, GoalItem goal) async {
    final amount = await showAllocateFundsDialog(context, goal: goal);
    if (amount != null && amount > 0) {
      final success = await controller.allocateFunds(
        goal.id,
        amount,
        walletId: activeWalletId,
      );
      if (success) {
        final updatedGoal = controller.goals.firstWhere((g) => g.id == goal.id);
        if (updatedGoal.status == GoalStatus.completed) {
          onAction("🎉 Congratulations! You achieved your '${goal.title}' goal!");
        } else {
          onAction("Allocated ₱${amount.toInt()} to ${goal.title}.");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final margin = AppLayout.pageMargin(context);
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final goals = controller.goals;

        return RefreshIndicator(
          onRefresh: onRefresh,
          color: AppColors.primaryOrange,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              margin,
              20,
              margin,
              85 + bottomInset.bottom,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Header: Title + Subtitle & "+ Create Goal" Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Financial Goals',
                                  style: GoogleFonts.manrope(
                                    fontSize: isCompact ? 20 : 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFFF7EE),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Track your savings targets',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFC6B5AB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // "+ Create Goal" button
                          Container(
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFE57136),
                                  Color(0xFFF48648),
                                  Color(0xFFFF8D43),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33FF6A13),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _handleCreateGoal(context),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Center(
                                    child: Text(
                                      '+ Create Goal',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1D110C),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. Dynamic Goal Cards
                      if (goals.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Text(
                            'No goals yet. Tap "+ Create Goal" to begin tracking savings!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      else
                        for (final goal in goals) ...[
                          GoalCard(
                            goal: goal,
                            onAllocate: (g) => _handleAllocateFunds(context, g),
                          ),
                          const SizedBox(height: 14),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
