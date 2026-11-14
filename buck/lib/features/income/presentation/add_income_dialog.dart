import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/buck_overlay_dialog.dart';
import '../../expenses/presentation/screens/receipt_scanner_screen.dart';
import '../../finance/data/finance_models.dart';

/// Income sources offered in the Category field.
const incomeSources = [
  'Salary',
  'Allowance',
  'Freelance',
  'Business',
  'Investment',
  'Gift',
  'Other',
];

/// Values submitted by the Add Income form.
class AddIncomeRequest {
  final double amount;
  final String source;
  final DateTime receivedOn;
  final String description;

  const AddIncomeRequest({
    required this.amount,
    required this.source,
    required this.receivedOn,
    required this.description,
  });
}

/// Shows the Figma "Overlay / Add Income" (2236:321 / 2236:322) form with
/// smooth entry/exit animations.
/// [onSubmit] saves the income and throws a message string on failure.
/// Resolves to true when an income was saved.
Future<bool> showAddIncomeDialog(
  BuildContext context, {
  required Wallet wallet,
  required Future<void> Function(AddIncomeRequest request) onSubmit,
  VoidCallback? onScan,
  ScannedReceiptResult? initialReceipt,
}) async {
  final saved = await showBuckOverlayDialog<bool>(
    context: context,
    builder: (_) => AddIncomeDialog(
      wallet: wallet,
      onSubmit: onSubmit,
      onScan: onScan,
      initialReceipt: initialReceipt,
    ),
  );
  return saved ?? false;
}

class AddIncomeDialog extends StatefulWidget {
  final Wallet wallet;
  final Future<void> Function(AddIncomeRequest request) onSubmit;
  final VoidCallback? onScan;
  final ScannedReceiptResult? initialReceipt;

  const AddIncomeDialog({
    super.key,
    required this.wallet,
    required this.onSubmit,
    this.onScan,
    this.initialReceipt,
  });

  @override
  State<AddIncomeDialog> createState() => _AddIncomeDialogState();
}

class _AddIncomeDialogState extends State<AddIncomeDialog> {
  static final _dateFormat = DateFormat('MM/dd/yyyy');

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _source;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;
  ScannedReceiptResult? _scannedReceipt;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialReceipt;
    if (initial != null && !initial.manualEntryRequested) {
      _scannedReceipt = initial;
      _applyScannedReceipt(initial);
    }
  }

  void _applyScannedReceipt(ScannedReceiptResult receipt) {
    _amountController.text =
        receipt.amount > 0 ? receipt.amount.toStringAsFixed(2) : '';
    _descriptionController.text = receipt.description;
    _date = receipt.date;
    _source = _inferIncomeSource(receipt);
  }

  String _inferIncomeSource(ScannedReceiptResult receipt) {
    final text = '${receipt.description} ${receipt.rawText ?? ''}'.toLowerCase();
    if (RegExp(r'\b(?:salary|payroll|paycheck|wage|payslip|compensation)\b')
        .hasMatch(text)) {
      return 'Salary';
    }
    if (RegExp(r'\b(?:allowance|stipend|baon)\b').hasMatch(text)) {
      return 'Allowance';
    }
    if (RegExp(r'\b(?:freelance|consulting|contract|commission|gig|upwork|fiverr)\b')
        .hasMatch(text)) {
      return 'Freelance';
    }
    if (RegExp(r'\b(?:business|invoice|sales|revenue|payout|store|mart)\b')
        .hasMatch(text)) {
      return 'Business';
    }
    if (RegExp(r'\b(?:dividend|interest|investment|stock|bond|yield|crypto)\b')
        .hasMatch(text)) {
      return 'Investment';
    }
    if (RegExp(r'\b(?:gift|bonus|present|aguinaldo)\b').hasMatch(text)) {
      return 'Gift';
    }
    return 'Other';
  }

  Future<void> _handleScanTap() async {
    if (widget.onScan != null) {
      widget.onScan!();
      return;
    }
    final result = await showReceiptScanner(context);
    if (result != null && mounted) {
      setState(() {
        if (result.manualEntryRequested) {
          _scannedReceipt = null;
        } else {
          _scannedReceipt = result;
          _applyScannedReceipt(result);
        }
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryOrange,
            surface: AppColors.cardSurfaceAlt,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }
    if (_source == null) {
      setState(() => _error = 'Choose a category.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        AddIncomeRequest(
          amount: amount,
          source: _source!,
          receivedOn: _date,
          description: _descriptionController.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is String ? e : 'Could not save income. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassCardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.glassCardBorder, width: 1),
            boxShadow: const [
              BoxShadow(color: AppColors.glassCardGlow, blurRadius: 28),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                _header(),
                if (_scannedReceipt != null)
                  _IncomeOcrBanner(
                    receipt: _scannedReceipt!,
                    onRescan: _saving ? null : _handleScanTap,
                  ),
                if (_error != null) _ErrorBanner(_error!),
                _OverlayField(
                  label: 'Amount',
                  child: _input(
                    controller: _amountController,
                    hint: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                  ),
                ),
                _OverlayField(label: 'Category', child: _categoryField()),
                _OverlayField(
                  label: 'Date',
                  child: _InputBox(
                    onTap: _pickDate,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dateFormat.format(_date),
                            style: _valueStyle,
                          ),
                        ),
                        SvgPicture.asset('assets/icons/calendar.svg'),
                      ],
                    ),
                  ),
                ),
                _OverlayField(
                  label: 'Description',
                  child: _input(
                    controller: _descriptionController,
                    hint: 'Enter Description (optional)',
                  ),
                ),
                _submitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              Text(
                'NEW INCOME',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 18 / 15,
                  color: AppColors.textAccent,
                ),
              ),
              Text(
                'Add Income',
                style: GoogleFonts.inter(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  height: 32 / 25,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Row(
            spacing: 8,
            children: [
              Tooltip(
                message: 'Adds to your "${widget.wallet.name}" wallet balance.',
                triggerMode: TooltipTriggerMode.tap,
                child: SvgPicture.asset('assets/icons/info_circle.svg'),
              ),
              Semantics(
                button: true,
                label: 'Scan',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleScanTap,
                  child: SvgPicture.asset('assets/icons/scan_large.svg'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryField() {
    return _InputBox(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _source,
          isExpanded: true,
          dropdownColor: AppColors.inputBg,
          borderRadius: BorderRadius.circular(12),
          icon: SvgPicture.asset('assets/icons/select_chevron.svg'),
          hint: Text('Enter Category', style: _hintStyle),
          style: _valueStyle,
          items: [
            for (final source in incomeSources)
              DropdownMenuItem(value: source, child: Text(source)),
          ],
          onChanged: _saving ? null : (v) => setState(() => _source = v),
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return _InputBox(
      child: TextField(
        controller: controller,
        enabled: !_saving,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: _valueStyle,
        cursorColor: AppColors.primaryOrange,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: _hintStyle,
        ),
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: AppColors.raisedCream,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _saving ? null : _submit,
          child: Center(
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF1D110C),
                    ),
                  )
                : Text(
                    'Add Income',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 24 / 18,
                      color: const Color(0xFF1D110C),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  static final TextStyle _hintStyle = GoogleFonts.inter(
    fontSize: 16,
    height: 22 / 16,
    color: AppColors.textSecondary,
  );

  static final TextStyle _valueStyle = GoogleFonts.inter(
    fontSize: 16,
    height: 22 / 16,
    color: AppColors.textPrimary,
  );
}

/// Label above a 56px input box (Figma "Field / …", 91px tall).
class _OverlayField extends StatelessWidget {
  final String label;
  final Widget child;

  const _OverlayField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 20 / 14,
            color: AppColors.textPrimary,
          ),
        ),
        child,
      ],
    );
  }
}

class _InputBox extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _InputBox({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.subtleDivider, width: 1),
        ),
        child: child,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4A100B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEA4335).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        spacing: 10,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 18),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFFFD1D1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeOcrBanner extends StatelessWidget {
  final ScannedReceiptResult receipt;
  final VoidCallback? onRescan;

  const _IncomeOcrBanner({required this.receipt, this.onRescan});

  @override
  Widget build(BuildContext context) {
    final thumbBytes = receipt.imageBytes;
    return Container(
      key: const Key('income_ocr_verification_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: receipt.isLowQuality
              ? AppColors.amberAccent.withValues(alpha: 0.75)
              : AppColors.primaryOrange.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 36,
                  height: 36,
                  color: const Color(0xFF2A1914),
                  alignment: Alignment.center,
                  child: thumbBytes != null && thumbBytes.isNotEmpty
                      ? Image.memory(
                          thumbBytes,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        )
                      : const Icon(
                          Icons.receipt_long_outlined,
                          size: 18,
                          color: AppColors.primaryOrange,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.processingTimeMs != null
                          ? 'OCR Scanned (${receipt.processingTimeMs}ms)'
                          : 'OCR Scanned',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                    Text(
                      'Detected: ${formatPesoCents(receipt.amount)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRescan != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRescan,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      'Rescan',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (receipt.qualityWarning != null)
            Text(
              receipt.qualityWarning!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.amberAccent,
              ),
            ),
        ],
      ),
    );
  }
}
