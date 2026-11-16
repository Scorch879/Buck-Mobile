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
  final nameController = TextEditingController();
  final balanceController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<CreateWalletRequest>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: const Color(0xFF19100B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.glassCardBorder),
        ),
        title: Text(
          'Create New Wallet',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFD5E2F5),
          ),
        ),
        content: Form(
          key: formKey,
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
                    color: const Color(0xFFD98B5C),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: nameController,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Savings, Emergency Fund',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFFC6B5AB), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF24170F),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0x70785B4C)),
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
                    color: const Color(0xFFD98B5C),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFFC6B5AB), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF24170F),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0x70785B4C)),
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFFC6B5AB)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                final name = nameController.text.trim();
                final balance = double.parse(balanceController.text.trim());
                Navigator.of(ctx).pop(CreateWalletRequest(name: name, initialBalance: balance));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    },
  );
}
