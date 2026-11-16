import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../../../core/constants/dev_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/widgets/buck_footer_nav.dart';
import '../../../core/widgets/buck_header.dart';
import '../../../core/widgets/buck_screen_background.dart';
import '../../auth/data/auth_service.dart';
import '../../settings/data/settings_service.dart';
import 'widgets/profile_side_panel.dart';
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
import '../../ai/presentation/widgets/ai_report_dialog.dart';
import '../../ai/presentation/widgets/ai_floating_chat_bubble.dart';

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
  PageController? _pageController;
  int? _programmaticPageTarget;
  bool _menuOpen = false;
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

  String get _panelDisplayName {
    final profileName = _finance.snapshot?.displayName;
    if (profileName != null && profileName.trim().isNotEmpty) {
      return profileName.trim();
    }
    final user = _authService.currentUser;
    final metadata = user?.userMetadata ?? const {};
    final name = (metadata['full_name'] ?? metadata['username']) as String?;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    if (DevConfig.mockAdminSessionActive.value) return 'Dev Admin';
    final fallback = user?.email?.split('@').first;
    return (fallback != null && fallback.isNotEmpty) ? fallback : 'Buck Account';
  }

  String get _panelEmail {
    if (DevConfig.mockAdminSessionActive.value) {
      return '${DevConfig.adminEmail} (Dev Mode)';
    }
    final email = _authService.currentUser?.email;
    return (email != null && email.isNotEmpty) ? email : 'Signed in';
  }

  String get _panelConnectionLabel {
    if (DevConfig.mockAdminSessionActive.value) {
      return 'Connected in Dev Mode';
    }
    final user = _authService.currentUser;
    final isGoogle = user?.appMetadata['provider'] == 'google' ||
        (user?.identities?.any((id) => id.provider == 'google') ?? false);
    if (isGoogle) return 'Connected with Google';
    if (user != null) return 'Connected with Email';
    return 'Connected with Buck';
  }

  BuckSettingsContext get _panelSettingsContext {
    final isDevMode = DevConfig.mockAdminSessionActive.value;
    final user = _authService.currentUser;
    final isGoogle = !isDevMode &&
        (user?.appMetadata['provider'] == 'google' ||
            (user?.identities?.any((id) => id.provider == 'google') ?? false));
    return BuckSettingsContext(
      displayName: _panelDisplayName,
      email: _panelEmail,
      connectionLabel: _panelConnectionLabel,
      providerName: isDevMode
          ? 'Dev Mode'
          : isGoogle
              ? 'Google'
              : 'Buck Auth',
      isGoogleManaged: isGoogle,
      isDevMode: isDevMode,
    );
  }

  void _showMenuSheet() {
    if (_menuOpen) return;
    _menuOpen = true;
    showProfileSidePanel(
      context: context,
      displayName: _panelDisplayName,
      email: _panelEmail,
      connectionLabel: _panelConnectionLabel,
      settingsContext: _panelSettingsContext,
      onProfileUpdated: _finance.refresh,
      onShowMessage: _showMessage,
      onSignOut: () async {
        DevConfig.mockAdminSessionActive.value = false;
        await _authService.signOut();
      },
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
              child: WalletScreen(
                snapshot: snapshot,
                controller: _finance,
                onRefresh: _finance.refresh,
                onAddIncome: _addIncome,
                onScanIncome: _scanIncomeReceipt,
                onMessage: _showMessage,
                bottomInset: contentInset,
              ),
            ),
            KeyedSubtree(
              key: const ValueKey(BuckTab.expenses),
              child: ExpensesScreen(
                snapshot: snapshot,
                onRefresh: _finance.refresh,
                onAddExpense: () => _onQuickAction(QuickAction.addExpense),
                onScanReceipt: _scanReceipt,
                bottomInset: contentInset,
              ),
            ),
            KeyedSubtree(
              key: const ValueKey(BuckTab.home),
              child: HomeDashboardScreen(
                snapshot: snapshot,
                onQuickAction: _onQuickAction,
                onRefresh: _finance.refresh,
                onOpenReport: () => showAiReportDialog(
                  context: context,
                  onInsightUpdated: _finance.refresh,
                ),
                bottomInset: contentInset,
              ),
            ),
            KeyedSubtree(
              key: const ValueKey(BuckTab.stats),
              child: StatsScreen(
                snapshot: snapshot,
                onRefresh: _finance.refresh,
                bottomInset: contentInset,
              ),
            ),
            KeyedSubtree(
              key: const ValueKey(BuckTab.goals),
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
              BuckHeader(
                title: _welcomeTitle,
                onMenuTap: _showMenuSheet,
                onSwipeOpenMenu: _showMenuSheet,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;
                    if (height <= 0) return const SizedBox.shrink();
                    final fadeEnd =
                        ((height - footerBottom - footerHeight - 2) / height)
                            .clamp(0.0, 1.0);
                    final fadeStart =
                        ((height - footerBottom - footerHeight - 34) / height)
                            .clamp(0.0, fadeEnd);

                    return ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: const [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                          Colors.transparent,
                        ],
                        stops: [0.0, fadeStart, fadeEnd, 1.0],
                      ).createShader(bounds),
                      child: pageContent,
                    );
                  },
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
          Positioned.fill(
            child: AiFloatingChatBubble(
              bottomRestOffset: footerBottom + footerHeight + 12,
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
