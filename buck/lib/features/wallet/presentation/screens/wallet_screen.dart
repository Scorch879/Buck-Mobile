import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../finance/domain/finance_snapshot.dart';
import '../../../finance/presentation/finance_controller.dart';
import '../widgets/create_wallet_dialog.dart';
import '../widgets/manage_income_card.dart';
import '../widgets/manage_wallets_card.dart';
import '../widgets/wallet_history_card.dart';
import '../widgets/wallet_net_worth_sheet.dart';
import '../widgets/wallet_overview_card.dart';

enum _WalletViewTab { wallets, income }

/// Figma "Screen / Wallet — Buck" (#2426:1568)
/// Comprehensive Wallet screen with non-static, interactive balances, wallet management, income tracking, and activity history.
class WalletScreen extends StatefulWidget {
  final FinanceSnapshot snapshot;
  final FinanceController controller;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddIncome;
  final ValueChanged<String>? onMessage;
  final EdgeInsets bottomInset;

  const WalletScreen({
    super.key,
    required this.snapshot,
    required this.controller,
    required this.onRefresh,
    required this.onAddIncome,
    this.onMessage,
    this.bottomInset = EdgeInsets.zero,
  });

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  _WalletViewTab _activeTab = _WalletViewTab.wallets;

  Future<void> _handleNewWallet() async {
    final result = await showCreateWalletDialog(context);
    if (result != null) {
      try {
        await widget.controller.createWallet(
          name: result.name,
          initialBalance: result.initialBalance,
        );
        widget.onMessage?.call("Wallet '${result.name}' created successfully!");
      } catch (e) {
        widget.onMessage?.call(e.toString());
      }
    }
  }

  Future<void> _handleSelectActive(String walletId) async {
    try {
      await widget.controller.setActiveWallet(walletId);
      final wallet = widget.snapshot.wallets.firstWhere((w) => w.id == walletId);
      widget.onMessage?.call("Active wallet switched to '${wallet.name}'");
    } catch (e) {
      widget.onMessage?.call(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final margin = AppLayout.pageMargin(context);
    final s = widget.snapshot;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.primaryOrange,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          margin,
          20,
          margin,
          85 + widget.bottomInset.bottom,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 14,
                children: [
                  // 1. Page Title (Figma: #2426:1576)
                  Text(
                    'Wallets & balances',
                    style: GoogleFonts.manrope(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      height: 28 / 23,
                      color: const Color(0xFFFFF7EE),
                    ),
                  ),

                  // 2. Main Wallet Overview Card (Figma: #2446:754)
                  WalletOverviewCard(
                    snapshot: s,
                    onViewNetWorth: () => showWalletNetWorthSheet(context, s),
                  ),

                  // 3. Wallet & Income Tabs (Figma: #2426:1599)
                  _buildTabsRow(s),

                  // 4. Tab Content: Manage Wallets OR Manage Income
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _activeTab == _WalletViewTab.wallets
                        ? ManageWalletsCard(
                            key: const ValueKey('manage_wallets'),
                            wallets: s.wallets,
                            activeWalletId: s.activeWallet?.id,
                            onSelectActive: _handleSelectActive,
                            onNewWallet: _handleNewWallet,
                          )
                        : ManageIncomeCard(
                            key: const ValueKey('manage_income'),
                            incomes: s.allIncomes,
                            onAddIncome: widget.onAddIncome,
                          ),
                  ),

                  // 5. Wallet History Card (Figma: #2426:1630)
                  WalletHistoryCard(
                    expenses: s.allExpenses.isNotEmpty ? s.allExpenses : s.monthExpenseList,
                    incomes: s.allIncomes,
                    activeWalletId: s.activeWallet?.id,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsRow(FinanceSnapshot s) {
    return Row(
      children: [
        // Wallets tab (Figma: #2426:1600)
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _activeTab = _WalletViewTab.wallets),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _activeTab == _WalletViewTab.wallets
                    ? Colors.transparent
                    : const Color(0x66100B09),
                border: Border.all(
                  color: _activeTab == _WalletViewTab.wallets
                      ? const Color(0xFFFF994A)
                      : const Color(0x70785B4C),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Wallets',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _activeTab == _WalletViewTab.wallets
                          ? const Color(0xFFFF8E5D)
                          : const Color(0xFFC6B5AB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _activeTab == _WalletViewTab.wallets
                          ? const Color(0x26FF994A)
                          : const Color(0x33785B4C),
                    ),
                    child: Text(
                      '${s.wallets.length}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _activeTab == _WalletViewTab.wallets
                            ? const Color(0xFFFF8E5D)
                            : const Color(0xFFC6B5AB),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Income tab (Figma: #2426:1604)
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _activeTab = _WalletViewTab.income),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _activeTab == _WalletViewTab.income
                    ? Colors.transparent
                    : const Color(0x66100B09),
                border: Border.all(
                  color: _activeTab == _WalletViewTab.income
                      ? const Color(0xFFFF994A)
                      : const Color(0x70785B4C),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Income',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _activeTab == _WalletViewTab.income
                          ? const Color(0xFFFF8E5D)
                          : const Color(0xFFC6B5AB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _activeTab == _WalletViewTab.income
                          ? const Color(0x26FF994A)
                          : const Color(0x33785B4C),
                    ),
                    child: Text(
                      '${s.allIncomes.length}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _activeTab == _WalletViewTab.income
                            ? const Color(0xFFFF8E5D)
                            : const Color(0xFFC6B5AB),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
