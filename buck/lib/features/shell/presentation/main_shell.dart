import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/buck_footer_nav.dart';
import '../../../core/widgets/buck_header.dart';
import '../../../core/widgets/buck_screen_background.dart';
import '../../auth/data/auth_service.dart';
import 'buck_shell_dependencies.dart';
import 'profile_summary_view_model.dart';
import 'widgets/profile_side_panel.dart';
import '../../dashboard/presentation/screens/home_dashboard_screen.dart';
import '../../dashboard/presentation/widgets/quick_actions_card.dart';
import '../../expenses/presentation/add_expense_dialog.dart';
import '../../expenses/presentation/screens/expenses_screen.dart';
import '../../expenses/presentation/screens/receipt_scanner_screen.dart';
import '../../finance/data/finance_models.dart';
import '../../finance/presentation/finance_controller.dart';
import '../../goals/presentation/goals_controller.dart';
import '../../goals/presentation/screens/goals_screen.dart';
import '../../income/presentation/add_income_dialog.dart';
import '../../onboarding/data/onboarding_service.dart';
import '../../onboarding/presentation/buck_onboarding_overlay.dart';
import '../../onboarding/presentation/buck_onboarding_targets.dart';
import '../../stats/presentation/screens/stats_screen.dart';
import '../../wallet/presentation/screens/wallet_screen.dart';
import '../../wallet/presentation/widgets/create_wallet_dialog.dart';
import '../../wallet/presentation/widgets/transfer_funds_dialog.dart';
import '../../ai/presentation/widgets/ai_report_dialog.dart';
import '../../ai/presentation/widgets/ai_floating_chat_bubble.dart';

/// Signed-in app frame: backdrop, header, active page, floating footer nav.
class MainShell extends StatefulWidget {
  final BuckTab initialTab;

  /// Injected in tests; defaults to one backed by the live Supabase client.
  final FinanceController? financeController;
  final GoalsController? goalsController;
  final OnboardingService? onboardingService;
  final bool? showOnboardingOverride;

  const MainShell({
    super.key,
    this.initialTab = BuckTab.home,
    this.financeController,
    this.goalsController,
    this.onboardingService,
    this.showOnboardingOverride,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _authService = AuthService();
  final _onboardingTargets = BuckOnboardingTargets();
  late BuckTab _tab = widget.initialTab;
  PageController? _pageController;
  int? _programmaticPageTarget;
  bool _menuOpen = false;
  late bool _showOnboarding = widget.showOnboardingOverride ?? false;
  late final FinanceController _finance =
      widget.financeController ?? BuckShellDependencies.createFinanceController();
  late final GoalsController _goals =
      widget.goalsController ?? BuckShellDependencies.createGoalsController();

  OnboardingService get _onboarding =>
      widget.onboardingService ?? OnboardingService.instance;

  @override
  void initState() {
    super.initState();
    _finance.start();
    _goals.start();
    _checkOnboardingEligibility();
  }

  Future<void> _checkOnboardingEligibility() async {
    if (widget.showOnboardingOverride != null) return;
    final shouldShow = await _onboarding.shouldShowOnboardingForUser(
      _authService.currentUser,
    );
    if (!mounted || !shouldShow) return;
    setState(() => _showOnboarding = true);
  }

  void _completeOnboarding() {
    if (_showOnboarding) {
      setState(() => _showOnboarding = false);
    }
    _onboarding.completeOnboarding(_authService.currentUser);
  }

  PageController _ensurePageController() {
    return _pageController ??= PageController(initialPage: _tab.index);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    // Only dispose controllers this widget created.
    if (widget.financeController == null) _finance.dispose();
    if (widget.goalsController == null) _goals.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.horizontal &&
        notification is OverscrollNotification &&
        _tab == BuckTab.wallet &&
        notification.overscroll < -18) {
      _showMenuSheet();
    }
    return false;
  }

  ProfileSummaryViewModel get _profileSummary => ProfileSummaryViewModel.from(
        snapshot: _finance.snapshot,
        user: _authService.currentUser,
      );

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
    if (_menuOpen) return;
    _menuOpen = true;
    final profile = _profileSummary;
    showProfileSidePanel(
      context: context,
      displayName: profile.displayName,
      email: profile.email,
      connectionLabel: profile.connectionLabel,
      settingsContext: profile.settingsContext,
      onProfileUpdated: _finance.refresh,
      onShowMessage: _showMessage,
      onSignOut: _authService.signOut,
    ).whenComplete(() {
      if (mounted) {
        _menuOpen = false;
      } else {
        _menuOpen = false;
      }
    });
  }

  void _showComingSoon(String feature) =>
      _showMessage('$feature is coming soon.');

  Future<void> _addIncome({ScannedReceiptResult? initialReceipt}) async {
    final wallet = _finance.snapshot?.activeWallet;
    if (wallet == null) {
      _showMessage('Create or select a wallet first to add income.');
      return;
    }
    final saved = await showAddIncomeDialog(
      context,
      wallet: wallet,
      initialReceipt: initialReceipt,
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
    if (scanned.manualEntryRequested) {
      await _addExpense();
      return;
    }
    await _addExpense(initialReceipt: scanned);
  }

  Future<void> _scanIncomeReceipt() async {
    final scanned = await showReceiptScanner(context);
    if (scanned == null || !mounted) return;
    if (scanned.manualEntryRequested) {
      await _addIncome();
      return;
    }
    await _addIncome(initialReceipt: scanned);
  }

  Future<void> _transferFunds() async {
    final snapshot = _finance.snapshot;
    final wallets = snapshot?.wallets ?? const <Wallet>[];
    if (wallets.length < 2) {
      final shouldCreateWallet = await showTransferNeedsWalletsDialog(
        context,
        walletCount: wallets.length,
      );
      if (shouldCreateWallet == true && mounted) {
        final req = await showCreateWalletDialog(context);
        if (req != null && mounted) {
          try {
            await _finance.createWallet(
              name: req.name,
              initialBalance: req.initialBalance,
            );
            if (!mounted) return;
            _showMessage("Wallet '${req.name}' created!");
            final updatedWallets =
                _finance.snapshot?.wallets ?? const <Wallet>[];
            if (updatedWallets.length >= 2) {
              await _openTransferDialog(
                updatedWallets,
                activeWalletId: _finance.snapshot?.activeWallet?.id,
              );
            }
          } catch (e) {
            if (mounted) _showMessage(e.toString());
          }
        }
      }
      return;
    }

    await _openTransferDialog(
      wallets,
      activeWalletId: snapshot?.activeWallet?.id,
    );
  }

  Future<void> _openTransferDialog(
    List<Wallet> wallets, {
    String? activeWalletId,
  }) async {
    final result = await showTransferFundsDialog(
      context,
      wallets: wallets,
      activeWalletId: activeWalletId,
      onSubmit: (sourceId, targetId, amount) => _finance.transferFunds(
        sourceWalletId: sourceId,
        targetWalletId: targetId,
        amount: amount,
      ),
    );
    if (result != null && mounted) {
      _showMessage(
        'Transferred ${formatPesoCents(result.amount)} from ${result.sourceWallet.name} to ${result.targetWallet.name}.',
      );
    }
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
    if (_tab == tab) {
      return;
    }
    setState(() => _tab = tab);
    final pc = _pageController;
    if (pc == null || !pc.hasClients) return;
    if ((pc.page?.round() ?? _tab.index) == tab.index) return;
    _programmaticPageTarget = tab.index;
    pc
        .animateToPage(
          tab.index,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (mounted && _programmaticPageTarget == tab.index) {
            _programmaticPageTarget = null;
          }
        });
  }

  void _onQuickAction(QuickAction action) {
    switch (action) {
      case QuickAction.scanReceipt:
        _scanReceipt();
      case QuickAction.addIncome:
        _addIncome();
      case QuickAction.addExpense:
        _addExpense();
      case QuickAction.transfer:
        _transferFunds();
    }
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

    final controller = _ensurePageController();
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: PageView(
          controller: controller,
          onPageChanged: (index) {
            if (_programmaticPageTarget != null) {
              if (index == _programmaticPageTarget) {
                _programmaticPageTarget = null;
              }
              return;
            }
            final nextTab = BuckTab.values[index];
            if (_tab != nextTab) {
              setState(() => _tab = nextTab);
            }
          },
          children: [
            KeyedSubtree(
              key: const ValueKey(BuckTab.wallet),
              child: RepaintBoundary(
                child: WalletScreen(
                  snapshot: snapshot,
                  controller: _finance,
                  onRefresh: _finance.refresh,
                  onAddIncome: _addIncome,
                  onScanIncome: _scanIncomeReceipt,
                  onMessage: _showMessage,
                  bottomInset: contentInset,
                  onboardingTargets: _onboardingTargets,
                ),
              ),
            ),
            KeyedSubtree(
              key: const ValueKey(BuckTab.expenses),
              child: RepaintBoundary(
                child: ExpensesScreen(
                  snapshot: snapshot,
                  onRefresh: _finance.refresh,
                  onAddExpense: () => _onQuickAction(QuickAction.addExpense),
                  onScanReceipt: _scanReceipt,
                  bottomInset: contentInset,
                  onboardingTargets: _onboardingTargets,
                ),
              ),
            ),
            KeyedSubtree(
              key: const ValueKey(BuckTab.home),
              child: RepaintBoundary(
                child: HomeDashboardScreen(
                  snapshot: snapshot,
                  onQuickAction: _onQuickAction,
                  onRefresh: _finance.refresh,
                  onOpenReport: () => showAiReportDialog(
                    context: context,
                    onInsightUpdated: _finance.refresh,
                  ),
                  bottomInset: contentInset,
                  onboardingTargets: _onboardingTargets,
                ),
              ),
            ),
            KeyedSubtree(
              key: const ValueKey(BuckTab.stats),
              child: RepaintBoundary(
                child: StatsScreen(
                  snapshot: snapshot,
                  onRefresh: _finance.refresh,
                  bottomInset: contentInset,
                  onboardingTargets: _onboardingTargets,
                ),
              ),
            ),
            KeyedSubtree(
              key: const ValueKey(BuckTab.goals),
              child: RepaintBoundary(
                child: GoalsScreen(
                  controller: _goals,
                  activeWalletId: snapshot.activeWallet?.id,
                  activeWalletBalance: snapshot.activeWallet?.balance,
                  onRefresh: () async {
                    await _finance.refresh();
                    await _goals.refresh();
                  },
                  onAction: _showMessage,
                  bottomInset: contentInset,
                  onboardingTargets: _onboardingTargets,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Anchor the floating footer near the very bottom of the screen, leaving
    // only minimal clearance for gesture home indicators or browser bars.
    final footerBottom = AppLayout.footerBottomOffset(context);
    final contentInset = EdgeInsets.only(bottom: footerBottom + 24);

    return ListenableBuilder(
      listenable: _finance,
      builder: (context, _) => _scaffold(footerBottom, contentInset),
    );
  }

  Widget _scaffold(
    double footerBottom,
    EdgeInsets contentInset,
  ) {
    final palette = BuckPalette.of(context);
    final pageContent = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: _body(contentInset),
    );
    const footerHeight = BuckFooterNav.height;

    return Scaffold(
      backgroundColor: palette.shellBg,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: BuckScreenBackground()),
          ),
          Column(
            children: [
              RepaintBoundary(
                child: BuckHeader(
                  title: _profileSummary.welcomeTitle,
                  onMenuTap: _showMenuSheet,
                  onSwipeOpenMenu: _showMenuSheet,
                ),
              ),
              Expanded(child: pageContent),
            ],
          ),
          // Lightweight bottom edge feather behind the floating footer bar
          // (replaces full-screen ShaderMask saveLayer for smooth 60/120fps scrolling).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: footerBottom + footerHeight + 34,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.shellBg.withValues(alpha: 0.0),
                      palette.shellBg,
                      palette.shellBg,
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: footerBottom,
            child: RepaintBoundary(
              child: BuckFooterNav(
                activeTab: _tab,
                onTabSelected: _onTabSelected,
              ),
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: AiFloatingChatBubble(
                bottomRestOffset: footerBottom + footerHeight + 12,
              ),
            ),
          ),
          // Left-edge swipe-right zone so users can pull the Profile Side Panel
          // open from any tab without conflicting with full-width tab swipes or
          // header menu taps.
          Positioned(
            left: 0,
            top: AppLayout.topSafeInset(context) + BuckHeader.height,
            bottom: 0,
            width: 22,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              excludeFromSemantics: true,
              onHorizontalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 160) {
                  _showMenuSheet();
                }
              },
            ),
          ),
          if (_showOnboarding && _finance.snapshot != null)
            Positioned.fill(
              child: BuckOnboardingOverlay(
                targets: _onboardingTargets,
                currentTab: _tab,
                onNavigateToTab: _onTabSelected,
                onComplete: _completeOnboarding,
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
