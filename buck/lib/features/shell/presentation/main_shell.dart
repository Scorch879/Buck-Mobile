import 'package:flutter/material.dart';

import '../../../core/constants/dev_config.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buck_footer_nav.dart';
import '../../../core/widgets/buck_header.dart';
import '../../../core/widgets/buck_screen_background.dart';
import '../../auth/data/auth_service.dart';
import '../../dashboard/presentation/screens/home_dashboard_screen.dart';
import '../../dashboard/presentation/widgets/quick_actions_card.dart';
import '../../expenses/presentation/add_expense_dialog.dart';
import '../../expenses/presentation/screens/expenses_screen.dart';
import '../../expenses/presentation/screens/receipt_scanner_screen.dart';
import '../../finance/data/dev_finance_source.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/presentation/finance_controller.dart';
import '../../goals/data/goals_repository.dart';
import '../../goals/presentation/goals_controller.dart';
import '../../goals/presentation/screens/goals_screen.dart';
import '../../income/presentation/add_income_dialog.dart';
import '../../stats/presentation/screens/stats_screen.dart';
import '../../wallet/presentation/screens/wallet_screen.dart';

/// Signed-in app frame: backdrop, header, active page, floating footer nav.
class MainShell extends StatefulWidget {
  final BuckTab initialTab;

  /// Injected in tests; defaults to one backed by the live Supabase client.
  final FinanceController? financeController;
  final GoalsController? goalsController;

  const MainShell({
    super.key,
    this.initialTab = BuckTab.home,
    this.financeController,
    this.goalsController,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _authService = AuthService();
  late BuckTab _tab = widget.initialTab;
  late final FinanceController _finance =
      widget.financeController ??
      (SupabaseService.isInitialized
          ? FinanceController(FinanceRepository(SupabaseService.client))
          : FinanceController(DevFinanceSource()));
  late final GoalsController _goals =
      widget.goalsController ??
      (SupabaseService.isInitialized && !DevConfig.mockAdminSessionActive.value
          ? GoalsController(
              repository: GoalsRepository(SupabaseService.client),
            )
          : GoalsController());

  @override
  void initState() {
    super.initState();
    _finance.start();
    _goals.start();
  }

  @override
  void dispose() {
    // Only dispose controllers this widget created.
    if (widget.financeController == null) _finance.dispose();
    if (widget.goalsController == null) _goals.dispose();
    super.dispose();
  }

  String get _welcomeTitle {
    final profileName = _finance.snapshot?.displayName;
    if (profileName != null) return 'Welcome $profileName';
    final user = _authService.currentUser;
    final metadata = user?.userMetadata ?? const {};
    final name = (metadata['full_name'] ?? metadata['username']) as String?;
    final fallback = user?.email?.split('@').first;
    final display = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : fallback;
    return display == null ? 'Welcome' : 'Welcome $display';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.primaryOrange,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showMenuSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryOrange.withValues(alpha: 0.2),
                      border: Border.all(color: AppColors.primaryOrange),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.person, color: AppColors.primaryOrange),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _welcomeTitle,
                          style: AppTextStyles.h2.copyWith(fontSize: 16),
                        ),
                        Text(
                          DevConfig.mockAdminSessionActive.value
                              ? '${DevConfig.adminEmail} (Dev Mode)'
                              : (_authService.currentUser?.email ?? ''),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.dividerColor),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFFF6B6B)),
                title: const Text('Sign Out', style: TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.w600)),
                contentPadding: EdgeInsets.zero,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  DevConfig.mockAdminSessionActive.value = false;
                  await _authService.signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(String feature) =>
      _showMessage('$feature is coming soon.');

  Future<void> _addIncome() async {
    final wallet = _finance.snapshot?.activeWallet;
    if (wallet == null) {
      _showMessage('Create or select a wallet first to add income.');
      return;
    }
    final saved = await showAddIncomeDialog(
      context,
      wallet: wallet,
      onScan: _scanReceipt,
      onSubmit: (request) => _finance.addIncome(
        walletId: wallet.id,
        amount: request.amount,
        source: request.source,
        description: request.description,
        receivedOn: request.receivedOn,
      ),
    );
    if (saved && mounted) _showMessage('Income added to ${wallet.name}.');
  }

  Future<void> _addExpense({ScannedReceiptResult? initialReceipt}) async {
    final wallet = _finance.snapshot?.activeWallet;
    if (wallet == null) {
      _showMessage('Create or select a wallet first to add spending.');
      return;
    }
    final saved = await showAddExpenseDialog(
      context,
      wallet: wallet,
      initialReceipt: initialReceipt,
      onSubmit: (request) => _finance.addExpense(
        walletId: wallet.id,
        amount: request.amount,
        categoryName: request.categoryName,
        description: request.description,
        spentOn: request.spentOn,
      ),
    );
    if (saved && mounted) _showMessage('Expense added to ${wallet.name}.');
  }

  Future<void> _scanReceipt() async {
    final scanned = await showReceiptScanner(context);
    if (scanned == null || !mounted) return;
    await _addExpense(initialReceipt: scanned);
  }

  void _onTabSelected(BuckTab tab) {
    if (!BuckFooterNav.hasDesign(tab)) {
      _showComingSoon(switch (tab) {
        BuckTab.wallet => 'Wallet',
        BuckTab.stats => 'Stats',
        _ => 'This page',
      });
      return;
    }
    setState(() => _tab = tab);
  }

  void _onQuickAction(QuickAction action) {
    if (action == QuickAction.scanReceipt) {
      _scanReceipt();
      return;
    }
    if (action == QuickAction.addIncome) {
      _addIncome();
      return;
    }
    if (action == QuickAction.addExpense) {
      _addExpense();
      return;
    }
    _showComingSoon(switch (action) {
      QuickAction.scanReceipt => 'Scan Receipt',
      QuickAction.addExpense => 'Add Expense',
      QuickAction.transfer => 'Transfer',
      QuickAction.addIncome => 'Add Income',
    });
  }

  Widget _body(EdgeInsets contentInset) {
    final snapshot = _finance.snapshot;
    if (snapshot == null) {
      final error = _finance.error;
      if (error == null) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        );
      }
      return _LoadError(message: error, onRetry: _finance.refresh);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _tab == BuckTab.expenses
          ? KeyedSubtree(
              key: const ValueKey(BuckTab.expenses),
              child: ExpensesScreen(
                snapshot: snapshot,
                onRefresh: _finance.refresh,
                onAddExpense: () => _onQuickAction(QuickAction.addExpense),
                bottomInset: contentInset,
              ),
            )
          : _tab == BuckTab.goals
              ? KeyedSubtree(
                  key: const ValueKey(BuckTab.goals),
                  child: GoalsScreen(
                    controller: _goals,
                    activeWalletId: snapshot.activeWallet?.id,
                    onRefresh: () async {
                      await _finance.refresh();
                      await _goals.refresh();
                    },
                    onAction: _showMessage,
                    bottomInset: contentInset,
                  ),
                )
              : _tab == BuckTab.stats
                  ? KeyedSubtree(
                      key: const ValueKey(BuckTab.stats),
                      child: StatsScreen(
                        snapshot: snapshot,
                        onRefresh: _finance.refresh,
                        bottomInset: contentInset,
                      ),
                    )
                  : _tab == BuckTab.wallet
                      ? KeyedSubtree(
                          key: const ValueKey(BuckTab.wallet),
                          child: WalletScreen(
                            snapshot: snapshot,
                            controller: _finance,
                            onRefresh: _finance.refresh,
                            onAddIncome: _addIncome,
                            onMessage: _showMessage,
                            bottomInset: contentInset,
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey(BuckTab.home),
                          child: HomeDashboardScreen(
                        snapshot: snapshot,
                        onQuickAction: _onQuickAction,
                        onRefresh: _finance.refresh,
                        onOpenReport: () => _showComingSoon('Financial report'),
                        bottomInset: contentInset,
                      ),
                    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    // Anchor the floating footer near the very bottom of the screen, leaving
    // only minimal clearance for gesture home indicators on notched phones.
    final footerBottom = padding.bottom > 0
        ? (padding.bottom * 0.35).clamp(4.0, 10.0)
        : 4.0;
    final contentInset = EdgeInsets.only(bottom: footerBottom);

    return ListenableBuilder(
      listenable: _finance,
      builder: (context, _) => _scaffold(footerBottom, contentInset),
    );
  }

  Widget _scaffold(
    double footerBottom,
    EdgeInsets contentInset,
  ) {
    return Scaffold(
      backgroundColor: AppColors.screenGradientTop,
      body: Stack(
        children: [
          const Positioned.fill(child: BuckScreenBackground()),
          Column(
            children: [
              BuckHeader(
                title: _welcomeTitle,
                onMenuTap: _showMenuSheet,
              ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  removeBottom: true,
                  child: _body(contentInset),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: footerBottom,
            child: BuckFooterNav(
              activeTab: _tab,
              onTabSelected: _onTabSelected,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.textSecondary,
              size: 40,
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Try again',
                style: TextStyle(color: AppColors.primaryOrange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
