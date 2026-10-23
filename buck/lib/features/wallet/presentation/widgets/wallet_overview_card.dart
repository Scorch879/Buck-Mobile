import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../finance/data/finance_models.dart';
import '../../../finance/domain/finance_snapshot.dart';
import '../../../stats/domain/stats_data.dart';

/// Figma "Content" (#2446:754) / "Property 1=Variant2" (#2446:733)
/// Main wallet card showing active wallet balance, remaining capacity, category breakdown bar, and net worth link.
class WalletOverviewCard extends StatelessWidget {
  final FinanceSnapshot snapshot;
  final VoidCallback onViewNetWorth;

  const WalletOverviewCard({
    super.key,
    required this.snapshot,
    required this.onViewNetWorth,
  });

  @override
  Widget build(BuildContext context) {
    final activeWallet = snapshot.activeWallet;
    final walletName = activeWallet?.name ?? 'My Wallet';
    final balance = activeWallet?.balance ?? 0.0;
    final remainingPercent = snapshot.walletRemainingPercent ?? 100;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassCardBg,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: AppColors.glassCardBorder,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Wallet Title (Figma: #I2446:754;2446:740)
          Text(
            walletName,
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: const Color(0xFFD5E2F5),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // 2. Balance Amount & Status Pill (Figma: #I2446:754;2446:776)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatPesoCents(balance),
                    style: GoogleFonts.manrope(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x7D00415D), // rgba(0, 65, 93, 0.49)
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '+$remainingPercent%',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: const Color(0xFF56D3C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Multi-segment Bar (Figma: #I2446:754;2446:741)
          _buildSegmentedBar(activeWallet),
          const SizedBox(height: 16),

          // 4. Footer: Last Synced & View Net Worth (Figma: #I2446:754;2446:736)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Last synced: just now',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFC6B5AB),
                ),
              ),
              GestureDetector(
                onTap: onViewNetWorth,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'View Net Worth →',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFF8E5D),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedBar(Wallet? wallet) {
    // Collect expenditures on this wallet
    final walletExpenses = wallet == null
        ? const <ExpenseRecord>[]
        : snapshot.allExpenses.where((e) => e.walletId == wallet.id).toList();

    var sumShopping = 0.0;
    var sumBills = 0.0;
    var sumFood = 0.0;
    var sumTransport = 0.0;
    var sumOthers = 0.0;

    for (final e in walletExpenses) {
      final cat = StatsCalculator.mapCategory(e.categoryName);
      switch (cat) {
        case 'shopping':
          sumShopping += e.amount;
        case 'bills':
          sumBills += e.amount;
        case 'food':
          sumFood += e.amount;
        case 'transport':
          sumTransport += e.amount;
        default:
          sumOthers += e.amount;
      }
    }

    final balance = wallet?.balance ?? 0.0;
    final totalSpent = sumShopping + sumBills + sumFood + sumTransport + sumOthers;
    final totalCapacity = balance + totalSpent;

    if (totalCapacity <= 0) {
      return Container(
        height: 15,
        decoration: BoxDecoration(
          color: const Color(0xFF4A2D22),
          borderRadius: BorderRadius.circular(5),
        ),
      );
    }

    // Proportional flex shares (min flex 1 for non-zero categories)
    int flex(double amount) {
      if (amount <= 0) return 0;
      final share = (amount / totalCapacity * 100).round();
      return share < 1 ? 1 : share;
    }

    final fShopping = flex(sumShopping);
    final fBills = flex(sumBills);
    final fFood = flex(sumFood);
    final fTransport = flex(sumTransport);
    final fBalance = flex(balance + sumOthers);

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 15,
        child: Row(
          children: [
            if (fShopping > 0)
              Expanded(
                flex: fShopping,
                child: Container(
                  color: const Color(0xFF936CE4),
                  margin: const EdgeInsets.only(right: 2),
                ),
              ),
            if (fBills > 0)
              Expanded(
                flex: fBills,
                child: Container(
                  color: const Color(0xFF2F9E7C),
                  margin: const EdgeInsets.only(right: 2),
                ),
              ),
            if (fFood > 0)
              Expanded(
                flex: fFood,
                child: Container(
                  color: const Color(0xFFFF8E5D),
                  margin: const EdgeInsets.only(right: 2),
                ),
              ),
            if (fTransport > 0)
              Expanded(
                flex: fTransport,
                child: Container(
                  color: const Color(0xFF2A7D8C),
                  margin: const EdgeInsets.only(right: 2),
                ),
              ),
            if (fBalance > 0)
              Expanded(
                flex: fBalance,
                child: Container(
                  color: const Color(0xFF4A2D22),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
