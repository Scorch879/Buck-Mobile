import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../finance/domain/finance_snapshot.dart';

/// Modal bottom sheet displaying detailed net worth breakdown across all wallets.
void showWalletNetWorthSheet(BuildContext context, FinanceSnapshot snapshot) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF140C08),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final total = snapshot.totalNetWorth;

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x33FF994A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'TOTAL NET WORTH',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: const Color(0xFFD98B5C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatPesoCents(total),
                style: GoogleFonts.manrope(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFF7EE),
                ),
              ),
              Text(
                'Across ${snapshot.wallets.length} active wallets',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFFC6B5AB),
                ),
              ),
              const SizedBox(height: 20),

              // Wallets breakdown list
              for (final w in snapshot.wallets) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: w.id == snapshot.activeWallet?.id
                                  ? const Color(0xFF56D3C7)
                                  : const Color(0xFFFF994A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFD5E2F5),
                                ),
                              ),
                              if (w.id == snapshot.activeWallet?.id)
                                Text(
                                  'Primary Active Wallet',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF56D3C7),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatPesoCents(w.balance),
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFFF7EE),
                            ),
                          ),
                          Text(
                            total > 0
                                ? '${(w.balance / total * 100).round()}% of total'
                                : '0%',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFFC6B5AB),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0x1FFF994A), height: 8),
              ],
              const SizedBox(height: 16),

              // Close button
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: const Color(0xFF24170F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0x33FF994A)),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
