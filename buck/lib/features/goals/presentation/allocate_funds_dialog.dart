import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buck_overlay_dialog.dart';
import '../data/goal_model.dart';

Future<double?> showAllocateFundsDialog(
  BuildContext context, {
  required GoalItem goal,
}) {
  return showBuckOverlayDialog<double>(
    context: context,
    builder: (_) => AllocateFundsDialog(goal: goal),
  );
}

class AllocateFundsDialog extends StatefulWidget {
  final GoalItem goal;

  const AllocateFundsDialog({super.key, required this.goal});

  @override
  State<AllocateFundsDialog> createState() => _AllocateFundsDialogState();
}

class _AllocateFundsDialogState extends State<AllocateFundsDialog> {
  final _amountController = TextEditingController(text: '1000');
  String? _error;

  static const List<double> _quickAmounts = [500, 1000, 2500, 5000];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter an amount greater than 0.');
      return;
    }
    Navigator.of(context).pop(amount);
  }

  String _formatCurrency(double amount) {
    final integerPart = amount.toInt();
    final buffer = StringBuffer();
    final digits = integerPart.toString();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return '₱$buffer';
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassCardBorder, width: 1),
            boxShadow: const [
              BoxShadow(color: AppColors.glassCardGlow, blurRadius: 28),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Allocate Funds',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFFF7EE),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Transfer savings into ${goal.title}',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFC6B5AB),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Mini summary card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.inputBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Current Progress',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFC6B5AB)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${_formatCurrency(goal.currentAmount)} / ${_formatCurrency(goal.targetAmount)}',
                                style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          height: 6,
                          width: double.infinity,
                          color: const Color(0xFF4A2D22),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: goal.progress,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: goal.gradientColors),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_formatCurrency(goal.remaining)} remaining',
                          style: GoogleFonts.inter(fontSize: 11, color: goal.themeColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A100B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEA4335).withValues(alpha: 0.6)),
                    ),
                    child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFFFD1D1))),
                  ),
                  const SizedBox(height: 14),
                ],

                // Amount to Allocate
                Text(
                  'Amount to Transfer (₱)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC6B5AB),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.add_circle_outline, color: AppColors.primaryOrange, size: 20),
                    filled: true,
                    fillColor: AppColors.cardSurfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Increment Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final q in _quickAmounts)
                      InkWell(
                        onTap: () => setState(() => _amountController.text = q.toInt().toString()),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.cardSurfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.inputBorder, width: 1),
                          ),
                          child: Text(
                            '+₱${q.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),

                // Submit Button
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.gradientOrangeStart,
                        AppColors.gradientOrangeEnd,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33FF6A13),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _submit,
                    child: Text(
                      'Confirm Allocation',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1D110C),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
