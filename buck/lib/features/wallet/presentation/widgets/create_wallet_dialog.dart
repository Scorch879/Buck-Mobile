import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Request object representing a new wallet to be created.
class CreateWalletRequest {
  final String name;
  final double initialBalance;

  const CreateWalletRequest({
    required this.name,
    required this.initialBalance,
  });
}

/// Modal dialog prompting the user for a new wallet's name and initial budget.
Future<CreateWalletRequest?> showCreateWalletDialog(BuildContext context) {
  return showDialog<CreateWalletRequest>(
    context: context,
    builder: (_) => const _CreateWalletDialog(),
  );
}

class _CreateWalletDialog extends StatefulWidget {
  const _CreateWalletDialog();

  @override
  State<_CreateWalletDialog> createState() => _CreateWalletDialogState();
}

class _CreateWalletDialogState extends State<_CreateWalletDialog> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    final dialogBg =
        palette.isLight ? palette.cardSurface : const Color(0xFF19100B);
    final fieldFill =
        palette.isLight ? palette.inputBg : const Color(0xFF24170F);

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: palette.glassCardBorder),
      ),
      title: Text(
        'Create New Wallet',
        style: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: palette.cardTitle,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'WALLET NAME',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: palette.textAccent,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                style: GoogleFonts.inter(
                  color: palette.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Savings, Emergency Fund',
                  hintStyle: GoogleFonts.inter(
                    color: palette.textSecondary,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: fieldFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryOrange),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a wallet name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'STARTING BALANCE (₱)',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: palette.textAccent,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: GoogleFonts.inter(
                  color: palette.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: GoogleFonts.inter(
                    color: palette.textSecondary,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: fieldFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryOrange),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter starting balance';
                  }
                  final num = double.tryParse(value.trim());
                  if (num == null || num < 0) {
                    return 'Enter a valid positive number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(color: palette.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() == true) {
              final name = _nameController.text.trim();
              final balance = double.parse(_balanceController.text.trim());
              Navigator.of(context).pop(
                CreateWalletRequest(name: name, initialBalance: balance),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          child: Text(
            'Create Wallet',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D110C),
            ),
          ),
        ),
      ],
    );
  }
}
