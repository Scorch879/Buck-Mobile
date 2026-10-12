import 'package:flutter/material.dart';

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
import '../../finance/data/finance_repository.dart';
import '../../finance/presentation/finance_controller.dart';
import '../../income/presentation/add_income_dialog.dart';

/// Signed-in app frame: backdrop, header, active page, floating footer nav.
class MainShell extends StatefulWidget {
  final BuckTab initialTab;

  /// Injected in tests; defaults to one backed by the live Supabase client.
  final FinanceController? financeController;

  const MainShell({
    super.key,
    this.initialTab = BuckTab.home,
    this.financeController,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _authService = AuthService();
  late BuckTab _tab = widget.initialTab;
  late final FinanceController _finance =
      widget.financeController ??
      FinanceController(FinanceRepository(SupabaseService.client));

  @override
  void initState() {
    super.initState();
    _finance.start();
  }

  @override
  void dispose() {
    // Only dispose controllers this widget created.
    if (widget.financeController == null) _finance.dispose();
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
      onScan: () => _showComingSoon('Scan Receipt'),
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

  Future<void> _addExpense() async {
    final wallet = _finance.snapshot?.activeWallet;
    if (wallet == null) {
      _showMessage('Create or select a wallet first to add spending.');
      return;
    }
    final saved = await showAddExpenseDialog(
      context,
      wallet: wallet,
      onScan: () => _showComingSoon('Scan Receipt'),
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

  void _onTabSelected(BuckTab tab) {
    if (!BuckFooterNav.hasDesign(tab)) {
      _showComingSoon(switch (tab) {
        BuckTab.wallet => 'Wallet',
        BuckTab.stats => 'Stats',
        BuckTab.settings => 'Settings',
        _ => 'This page',
      });
      return;
    }
    setState(() => _tab = tab);
  }

  void _onQuickAction(QuickAction action) {
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
    final padding = MediaQuery.paddingOf(context);
    // Figma: footer floats 12px above the system navigation area.
    final footerBottom = padding.bottom + 12;
    final contentInset = EdgeInsets.only(bottom: footerBottom);

    return ListenableBuilder(
      listenable: _finance,
      builder: (context, _) => _scaffold(padding, footerBottom, contentInset),
    );
  }

  Widget _scaffold(
    EdgeInsets padding,
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
              // System / Status Bar strip
              Container(height: padding.top, color: AppColors.navBarBg),
              BuckHeader(
                title: _welcomeTitle,
                onMenuTap: () => _showComingSoon('Menu'),
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
