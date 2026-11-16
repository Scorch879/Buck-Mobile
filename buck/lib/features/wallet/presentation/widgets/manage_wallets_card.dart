import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../finance/data/finance_models.dart';

enum WalletSortOption {
  highestBudget('Highest Budget'),
  lowestBudget('Lowest Budget'),
  name('Name');

  final String label;
  const WalletSortOption(this.label);
}

/// Figma "Manage your wallets" (#2426:1608)
/// Interactive card to search, sort, switch active wallet, and create new wallets.
class ManageWalletsCard extends StatefulWidget {
  final List<Wallet> wallets;
  final String? activeWalletId;
  final ValueChanged<String> onSelectActive;
  final VoidCallback onNewWallet;

  const ManageWalletsCard({
    super.key,
    required this.wallets,
    required this.activeWalletId,
    required this.onSelectActive,
    required this.onNewWallet,
  });

  @override
  State<ManageWalletsCard> createState() => _ManageWalletsCardState();
}

class _ManageWalletsCardState extends State<ManageWalletsCard> {
  String _searchQuery = '';
  WalletSortOption _sortOption = WalletSortOption.highestBudget;

  @override
  Widget build(BuildContext context) {
    // 1. Filter by search query
    final filtered = widget.wallets.where((w) {
      if (_searchQuery.isEmpty) return true;
      return w.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // 2. Sort by chosen option
    filtered.sort((a, b) {
      switch (_sortOption) {
        case WalletSortOption.highestBudget:
          return b.balance.compareTo(a.balance);
        case WalletSortOption.lowestBudget:
          return a.balance.compareTo(b.balance);
        case WalletSortOption.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC080503), // rgba(8, 5, 3, 0.8)
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFFF994A),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2EFF6A13),
            blurRadius: 28,
            offset: Offset(0, 0),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Section Header (Figma: #2426:1609)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Manage your wallets',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFD5E2F5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.wallets.length} wallets',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFC6B5AB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Search and Refine Controls (Figma: #2426:1612)
          Row(
            children: [
              // Search input
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF24170F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0x70785B4C),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 16,
                        color: Color(0xFFC6B5AB),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFFFFF7EE),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search wallets...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFFC6B5AB),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sort dropdown button
              PopupMenuButton<WalletSortOption>(
                onSelected: (opt) => setState(() => _sortOption = opt),
                color: const Color(0xFF24170F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0x70785B4C)),
                ),
                itemBuilder: (ctx) => [
                  for (final opt in WalletSortOption.values)
                    PopupMenuItem(
                      value: opt,
                      child: Text(
                        opt.label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _sortOption == opt
                              ? AppColors.primaryOrange
                              : const Color(0xFFFFF7EE),
                          fontWeight: _sortOption == opt ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF24170F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0x70785B4C),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sortOption.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFFF7EE),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: Color(0xFFC6B5AB),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Wallets List or Empty State (Figma: #2426:1621)
          if (filtered.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final wallet = filtered[index];
                final isActive = wallet.id == widget.activeWalletId;

                return GestureDetector(
                  onTap: () => widget.onSelectActive(wallet.id),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0x2EFF994A)
                          : const Color(0xFF19100B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFFFF994A)
                            : const Color(0x33785B4C),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Wallet Symbol Container (Figma: #2426:1622)
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0x17FF994A), // rgba(255, 153, 74, 0.09)
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0x33FF994A), // rgba(255, 153, 74, 0.2)
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 20,
                            color: Color(0xFFFF8E5D),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Name & Balance
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                wallet.name,
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFFFF7EE),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatPesoCents(wallet.balance),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFF8E5D),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Active Indicator / Switch action
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0x3356D3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF56D3C7),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check, size: 12, color: Color(0xFF56D3C7)),
                                const SizedBox(width: 4),
                                Text(
                                  'Active',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF56D3C7),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          TextButton(
                            onPressed: () => widget.onSelectActive(wallet.id),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Set Active',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFC6B5AB),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),

          // 4. "+ New Wallet" Button (Figma: #2426:1628)
          GestureDetector(
            onTap: widget.onNewWallet,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE57136),
                    Color(0xFFF48648),
                    Color(0xFFFF8D43),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '+ New Wallet',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D110C),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Empty symbol (Figma: #2426:1622)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0x17FF994A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0x33FF994A),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              size: 26,
              color: Color(0xFFFF8E5D),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No wallets yet',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFFF7EE),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Create a wallet to start managing your money.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFC6B5AB),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
