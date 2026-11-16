import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../finance/domain/finance_snapshot.dart';

/// Modal bottom sheet displaying detailed net worth breakdown across all wallets.
void showWalletNetWorthSheet(BuildContext context, FinanceSnapshot snapshot) {
  final palette = BuckPalette.of(context);
  final sheetBg =
      palette.isLight ? palette.cardSurface : const Color(0xFF140C08);
  final activeCyan =
      palette.isLight ? const Color(0xFF00796B) : const Color(0xFF56D3C7);

  showModalBottomSheet(
    context: context,
    backgroundColor: sheetBg,
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
                    color: AppColors.headerBorder.withValues(alpha: 0.3),
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
                  color: palette.textAccent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatPesoCents(total),
                style: GoogleFonts.manrope(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                'Across ${snapshot.wallets.length} active wallets',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: palette.textSecondary,
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
                                  ? activeCyan
                                  : AppColors.headerBorder,
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
                                  color: palette.cardTitle,
                                ),
                              ),
                              if (w.id == snapshot.activeWallet?.id)
                                Text(
                                  'Primary Active Wallet',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: activeCyan,
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
                              color: palette.textPrimary,
                            ),
                          ),
                          Text(
                            total > 0
                                ? '${(w.balance / total * 100).round()}% of total'
                                : '0%',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(color: palette.divider, height: 8),
              ],
              const SizedBox(height: 16),

              // Close button
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: palette.surfaceElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: palette.border),
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
