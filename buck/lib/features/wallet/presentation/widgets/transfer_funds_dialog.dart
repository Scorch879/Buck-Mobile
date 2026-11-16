import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/buck_overlay_dialog.dart';
import '../../../finance/data/finance_models.dart';

/// Prompts the user to create at least 2 wallets before using Wallet Transfer.
/// Returns `true` when the user taps '+ Create Wallet'.
Future<bool?> showTransferNeedsWalletsDialog(
  BuildContext context, {
  required int walletCount,
}) {
  return showBuckOverlayDialog<bool>(
    context: context,
    builder: (ctx) => _TransferNeedsWalletsDialog(walletCount: walletCount),
  );
}

class _TransferNeedsWalletsDialog extends StatelessWidget {
  final int walletCount;

  const _TransferNeedsWalletsDialog({required this.walletCount});

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    final needed = walletCount == 0 ? 2 : 1;
    final currentText = walletCount == 0
        ? 'You do not have any wallets yet.'
        : 'You currently have 1 wallet.';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: BoxDecoration(
            color: palette.glassCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.glassCardBorder, width: 1),
            boxShadow: [
              BoxShadow(color: palette.glassCardGlow, blurRadius: 28),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.headerBorder.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      color: AppColors.primaryOrange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WALLET TRANSFER',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: palette.textAccent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Need 2 or More Wallets',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: palette.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '$currentText Add at least $needed more ${needed == 1 ? 'wallet' : 'wallets'} so you can transfer funds between separate wallets.',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  height: 1.5,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: palette.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Later',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      key: const Key('transfer_create_wallet_cta'),
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '+ Create Wallet',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Request payload returned when transferring funds between two wallets.
class TransferFundsRequest {
  final Wallet sourceWallet;
  final Wallet targetWallet;
  final double amount;

  const TransferFundsRequest({
    required this.sourceWallet,
    required this.targetWallet,
    required this.amount,
  });
}

/// Opens the Wallet Transfer dialog when the user has at least 2 wallets.
/// Returns the completed [TransferFundsRequest] if confirmed, otherwise `null`.
Future<TransferFundsRequest?> showTransferFundsDialog(
  BuildContext context, {
  required List<Wallet> wallets,
  String? activeWalletId,
  required Future<void> Function(
    String sourceWalletId,
    String targetWalletId,
    double amount,
  ) onSubmit,
}) async {
  assert(wallets.length >= 2, 'Transfer requires at least 2 wallets.');
  return showBuckOverlayDialog<TransferFundsRequest>(
    context: context,
    builder: (_) => _TransferFundsDialog(
      wallets: wallets,
      activeWalletId: activeWalletId,
      onSubmit: onSubmit,
    ),
  );
}

class _TransferFundsDialog extends StatefulWidget {
  final List<Wallet> wallets;
  final String? activeWalletId;
  final Future<void> Function(
    String sourceWalletId,
    String targetWalletId,
    double amount,
  ) onSubmit;

  const _TransferFundsDialog({
    required this.wallets,
    required this.activeWalletId,
    required this.onSubmit,
  });

  @override
  State<_TransferFundsDialog> createState() => _TransferFundsDialogState();
}

class _TransferFundsDialogState extends State<_TransferFundsDialog> {
  final _amountController = TextEditingController();
  late String _sourceId;
  late String _targetId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final hasActive = widget.activeWalletId != null &&
        widget.wallets.any((w) => w.id == widget.activeWalletId);
    _sourceId = hasActive ? widget.activeWalletId! : widget.wallets.first.id;
    _targetId = widget.wallets.firstWhere((w) => w.id != _sourceId).id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Wallet get _sourceWallet =>
      widget.wallets.firstWhere((w) => w.id == _sourceId);

  Wallet get _targetWallet =>
      widget.wallets.firstWhere((w) => w.id == _targetId);

  void _onSourceChanged(String? nextId) {
    if (nextId == null || _saving) return;
    setState(() {
      _error = null;
      if (nextId == _targetId) {
        _targetId = _sourceId;
      }
      _sourceId = nextId;
    });
  }

  void _onTargetChanged(String? nextId) {
    if (nextId == null || _saving) return;
    setState(() {
      _error = null;
      if (nextId == _sourceId) {
        _sourceId = _targetId;
      }
      _targetId = nextId;
    });
  }

  void _swapWallets() {
    if (_saving) return;
    setState(() {
      _error = null;
      final prevSource = _sourceId;
      _sourceId = _targetId;
      _targetId = prevSource;
    });
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }
    if (_sourceId == _targetId) {
      setState(() => _error = 'Choose two different wallets.');
      return;
    }
    final source = _sourceWallet;
    final target = _targetWallet;
    if (amount > source.balance) {
      setState(
        () => _error =
            'Insufficient balance in ${source.name} (${formatPesoCents(source.balance)} available).',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(source.id, target.id, amount);
      if (!mounted) return;
      Navigator.of(context).pop(
        TransferFundsRequest(
          sourceWallet: source,
          targetWallet: target,
          amount: amount,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is String ? e : 'Could not transfer funds. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    final source = _sourceWallet;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            color: palette.glassCardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.glassCardBorder, width: 1),
            boxShadow: [
              BoxShadow(color: palette.glassCardGlow, blurRadius: 28),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                _buildHeader(palette),
                if (_error != null) _buildErrorBanner(palette, _error!),
                _buildWalletDropdown(
                  key: const Key('transfer_source_dropdown'),
                  palette: palette,
                  label: 'From Wallet',
                  selectedId: _sourceId,
                  onChanged: _onSourceChanged,
                ),
                Center(
                  child: InkWell(
                    key: const Key('transfer_swap_button'),
                    onTap: _saving ? null : _swapWallets,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: palette.inputBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.border),
                      ),
                      child: const Icon(
                        Icons.swap_vert_rounded,
                        color: AppColors.primaryOrange,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                _buildWalletDropdown(
                  key: const Key('transfer_target_dropdown'),
                  palette: palette,
                  label: 'To Wallet',
                  selectedId: _targetId,
                  onChanged: _onTargetChanged,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Amount',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                        GestureDetector(
                          onTap: _saving || source.balance <= 0
                              ? null
                              : () {
                                  setState(() {
                                    _error = null;
                                    _amountController.text =
                                        source.balance.toStringAsFixed(2);
                                  });
                                },
                          child: Text(
                            'Available: ${formatPesoCents(source.balance)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: palette.textAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: palette.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.divider, width: 1),
                      ),
                      child: TextField(
                        key: const Key('transfer_amount_input'),
                        controller: _amountController,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: palette.textPrimary,
                        ),
                        cursorColor: AppColors.primaryOrange,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: '0.00',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 16,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 54,
                  child: Material(
                    color: palette.isLight
                        ? AppColors.primaryOrange
                        : AppColors.raisedCream,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      key: const Key('transfer_submit_button'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: _saving ? null : _submit,
                      child: Center(
                        child: _saving
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: palette.isLight
                                      ? Colors.white
                                      : const Color(0xFF1D110C),
                                ),
                              )
                            : Text(
                                'Transfer Funds',
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: palette.isLight
                                      ? Colors.white
                                      : const Color(0xFF1D110C),
                                ),
                              ),
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

  Widget _buildHeader(BuckPalette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                'WALLET TRANSFER',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: palette.textAccent,
                ),
              ),
              Text(
                'Transfer Funds',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: palette.textSecondary, size: 22),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildWalletDropdown({
    required Key key,
    required BuckPalette palette,
    required String label,
    required String selectedId,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
        ),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: palette.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.divider, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: key,
              value: selectedId,
              isExpanded: true,
              dropdownColor: palette.inputBg,
              borderRadius: BorderRadius.circular(12),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: palette.textSecondary,
              ),
              style: GoogleFonts.inter(
                fontSize: 15,
                color: palette.textPrimary,
              ),
              items: [
                for (final w in widget.wallets)
                  DropdownMenuItem(
                    value: w.id,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            w.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatPesoCents(w.balance),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.textAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: _saving ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(BuckPalette palette, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.dangerSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.dangerBorder),
      ),
      child: Row(
        spacing: 10,
        children: [
          Icon(Icons.error_outline, color: palette.dangerTitle, size: 18),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: palette.dangerTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
