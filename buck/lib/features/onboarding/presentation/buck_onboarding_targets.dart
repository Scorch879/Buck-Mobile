import 'package:flutter/widgets.dart';

/// Holds optional [GlobalKey] anchors used by the new-user onboarding overlay
/// to scroll to and spotlight exact live UI targets across the 5 shell tabs.
class BuckOnboardingTargets {
  final GlobalKey quickActionsCardKey = GlobalKey(
    debugLabel: 'onboarding_quick_actions_card',
  );
  final GlobalKey addExpenseActionKey = GlobalKey(
    debugLabel: 'onboarding_add_expense_action',
  );
  final GlobalKey addIncomeActionKey = GlobalKey(
    debugLabel: 'onboarding_add_income_action',
  );
  final GlobalKey manageWalletsCardKey = GlobalKey(
    debugLabel: 'onboarding_manage_wallets_card',
  );
  final GlobalKey newWalletButtonKey = GlobalKey(
    debugLabel: 'onboarding_new_wallet_button',
  );
  final GlobalKey recentExpensesCardKey = GlobalKey(
    debugLabel: 'onboarding_recent_expenses_card',
  );
  final GlobalKey expensesAddButtonKey = GlobalKey(
    debugLabel: 'onboarding_expenses_add_button',
  );
  final GlobalKey goalsHeroSectionKey = GlobalKey(
    debugLabel: 'onboarding_goals_hero_section',
  );
  final GlobalKey createGoalButtonKey = GlobalKey(
    debugLabel: 'onboarding_create_goal_button',
  );
  final GlobalKey allocateFundsButtonKey = GlobalKey(
    debugLabel: 'onboarding_allocate_funds_button',
  );
  final GlobalKey categoryBreakdownCardKey = GlobalKey(
    debugLabel: 'onboarding_category_breakdown_card',
  );
  final GlobalKey spendingTrendCardKey = GlobalKey(
    debugLabel: 'onboarding_spending_trend_card',
  );
  final GlobalKey categoryPeriodPillsKey = GlobalKey(
    debugLabel: 'onboarding_category_period_pills',
  );
  final GlobalKey trendPeriodPillsKey = GlobalKey(
    debugLabel: 'onboarding_trend_period_pills',
  );
}
