import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buck_overlay_dialog.dart';
import '../../ai/data/services/buck_ai_service.dart';
import '../../finance/data/finance_models.dart';
import 'screens/receipt_scanner_screen.dart';

/// Categories offered in the Category field for spending.
const List<String> expenseCategories = mobileExpenseCategories;

/// Values submitted by the Add Expense / Spending form.
class AddExpenseRequest {
  final double amount;
  final String categoryName;
  final DateTime spentOn;
  final String description;

  const AddExpenseRequest({
    required this.amount,
    required this.categoryName,
    required this.spentOn,
    required this.description,
  });
}

/// Shows the Figma "Overlay / Add Spending" (2236:320 / 2236:356) form with
/// smooth entry/exit animations.
/// [onSubmit] saves the expense and throws a message string on failure.
/// Resolves to true when an expense was saved.
Future<bool> showAddExpenseDialog(
  BuildContext context, {
  required Wallet wallet,
  required Future<void> Function(AddExpenseRequest request) onSubmit,
  VoidCallback? onScan,
  ScannedReceiptResult? initialReceipt,
  BuckAiService? aiService,
}) async {
  final saved = await showBuckOverlayDialog<bool>(
    context: context,
    builder: (_) => AddExpenseDialog(
      wallet: wallet,
      onSubmit: onSubmit,
      onScan: onScan,
      initialReceipt: initialReceipt,
      aiService: aiService,
    ),
  );
  return saved ?? false;
}

class AddExpenseDialog extends StatefulWidget {
  final Wallet wallet;
  final Future<void> Function(AddExpenseRequest request) onSubmit;
  final VoidCallback? onScan;
  final ScannedReceiptResult? initialReceipt;
  final BuckAiService? aiService;

  const AddExpenseDialog({
    super.key,
    required this.wallet,
    required this.onSubmit,
    this.onScan,
    this.initialReceipt,
    this.aiService,
  });

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  static final _dateFormat = DateFormat('MM/dd/yyyy');

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _category;
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _autoCategorizing = false;
  String? _error;
  late final BuckAiService _aiService = widget.aiService ?? BuckAiService.instance;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialReceipt;
    if (initial != null) {
      _applyScannedReceipt(initial);
    }
  }

  void _applyScannedReceipt(ScannedReceiptResult receipt) {
    _amountController.text = receipt.amount.toStringAsFixed(2);
    _descriptionController.text = receipt.description;
    _date = receipt.date;
    if (expenseCategories.contains(receipt.categoryName)) {
      _category = receipt.categoryName;
    } else {
      final desc = receipt.description.trim();
      final isPlaceholderScan = desc.toLowerCase().startsWith('scanned receipt');
      if (desc.isNotEmpty && !isPlaceholderScan) {
        _category = BuckAiService.mapToMobileCategory(
          receipt.categoryName,
          fallbackDescription: desc,
        );
        _autoCategorize(text: desc, onlyIfUnset: false);
      } else {
        _category = 'Shopping';
      }
    }
  }

  Future<void> _autoCategorize({String? text, bool onlyIfUnset = false}) async {
    if (onlyIfUnset && _category != null) return;

    final desc = (text ?? _descriptionController.text).trim();
    if (desc.isEmpty) return;

    final categoryBeforeRequest = _category;
    setState(() => _autoCategorizing = true);
    try {
      final categories = await _aiService.categorize(descriptions: [desc]);
      if (categories.isNotEmpty && mounted) {
        // Respect any manual category selection made while the request was in flight.
        if ((onlyIfUnset && _category != null) ||
            _category != categoryBeforeRequest) {
          return;
        }
        final mapped = BuckAiService.mapToMobileCategory(
          categories.first,
          fallbackDescription: desc,
        );
        setState(() {
          _category = mapped;
          _error = null;
        });
      }
    } catch (_) {
      // Graceful fallback
    } finally {
      if (mounted) setState(() => _autoCategorizing = false);
    }
  }

  Future<void> _handleScanTap() async {
    if (widget.onScan != null) {
      widget.onScan!();
      return;
    }
    final result = await showReceiptScanner(context);
    if (result != null && mounted) {
      setState(() {
        _applyScannedReceipt(result);
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
    if (_category == null) {
      setState(() => _error = 'Choose a category.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        AddExpenseRequest(
          amount: amount,
          categoryName: _category!,
          spentOn: _date,
          description: _descriptionController.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is String ? e : 'Could not save expense. Please try again.';
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
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _descriptionController,
                  builder: (context, descValue, _) {
                    final hasDesc = descValue.text.trim().isNotEmpty;
                    return _OverlayField(
                      label: 'Category',
                      trailing: hasDesc
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _autoCategorizing
                                  ? null
                                  : () => _autoCategorize(onlyIfUnset: false),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    size: 13,
                                    color: AppColors.amberAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'AI Detect',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.amberAccent,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : null,
                      child: _categoryField(),
                    );
                  },
                ),
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
                    onEditingComplete: () {
                      _autoCategorize(onlyIfUnset: true);
                      FocusScope.of(context).unfocus();
                    },
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
                'NEW SPENDING',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 18 / 15,
                  color: AppColors.textAccent,
                ),
              ),
              Text(
                'Add Spending',
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
                message:
                    'Deducts from your "${widget.wallet.name}" wallet balance.',
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
          value: _category,
          isExpanded: true,
          dropdownColor: AppColors.inputBg,
          borderRadius: BorderRadius.circular(12),
          icon: _autoCategorizing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryOrange,
                  ),
                )
              : SvgPicture.asset('assets/icons/select_chevron.svg'),
          hint: Text(
            _autoCategorizing ? 'AI detecting category...' : 'Enter Category',
            style: _hintStyle,
          ),
          style: _valueStyle,
          items: [
            for (final cat in expenseCategories)
              DropdownMenuItem(value: cat, child: Text(cat)),
          ],
          onChanged: _saving ? null : (v) => setState(() => _category = v),
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    VoidCallback? onEditingComplete,
  }) {
    return _InputBox(
      child: TextField(
        controller: controller,
        enabled: !_saving,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onEditingComplete: onEditingComplete,
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
                    'Add Expense',
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
  final Widget? trailing;
  final Widget child;

  const _OverlayField({
    required this.label,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            if (trailing != null) trailing!,
          ],
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
