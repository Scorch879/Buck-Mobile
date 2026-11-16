import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buck_overlay_dialog.dart';

class CreateGoalResult {
  final String title;
  final double targetAmount;
  final double initialAmount;
  final String targetDate;
  final IconData icon;
  final Color themeColor;
  final List<Color> gradientColors;

  const CreateGoalResult({
    required this.title,
    required this.targetAmount,
    required this.initialAmount,
    required this.targetDate,
    required this.icon,
    required this.themeColor,
    required this.gradientColors,
  });
}

Future<CreateGoalResult?> showCreateGoalDialog(BuildContext context) {
  return showBuckOverlayDialog<CreateGoalResult>(
    context: context,
    builder: (_) => const CreateGoalDialog(),
  );
}

class CreateGoalDialog extends StatefulWidget {
  const CreateGoalDialog({super.key});

  @override
  State<CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends State<CreateGoalDialog> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _initialController = TextEditingController();
  DateTime _targetDate = DateTime(DateTime.now().year + 1, DateTime.now().month);
  String? _error;

  static const List<_PresetCategory> _presets = [
    _PresetCategory(
      label: 'Emergency',
      icon: Icons.shield_outlined,
      color: Color(0xFFFF8E5D),
      gradient: [Color(0xFFFF8E5D), Color(0xFFFF6A13)],
    ),
    _PresetCategory(
      label: 'Travel',
      icon: Icons.location_on_outlined,
      color: Color(0xFF9B72F2),
      gradient: [Color(0xFF9B72F2), Color(0xFF7C3AED)],
    ),
    _PresetCategory(
      label: 'Gadgets',
      icon: Icons.laptop_mac_outlined,
      color: Color(0xFF35B9D3),
      gradient: [Color(0xFF35B9D3), Color(0xFF00CCFF)],
    ),
    _PresetCategory(
      label: 'Home',
      icon: Icons.home_outlined,
      color: Color(0xFF4ADE80),
      gradient: [Color(0xFF4ADE80), Color(0xFF22C55E)],
    ),
    _PresetCategory(
      label: 'Vehicle',
      icon: Icons.directions_car_outlined,
      color: Color(0xFFF59E0B),
      gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
    ),
  ];

  late _PresetCategory _selectedPreset = _presets.first;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _initialController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final palette = BuckPalette.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2040),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: palette.isLight
              ? ColorScheme.light(
                  primary: AppColors.primaryOrange,
                  surface: palette.cardSurface,
                )
              : const ColorScheme.dark(
                  primary: AppColors.primaryOrange,
                  surface: AppColors.cardSurfaceAlt,
                ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter a goal name.');
      return;
    }

    final target = double.tryParse(_targetController.text.replaceAll(',', ''));
    if (target == null || target <= 0) {
      setState(() => _error = 'Please enter a valid target amount greater than 0.');
      return;
    }

    final initialText = _initialController.text.replaceAll(',', '').trim();
    final initial = initialText.isEmpty ? 0.0 : (double.tryParse(initialText) ?? 0.0);

    Navigator.of(context).pop(
      CreateGoalResult(
        title: title,
        targetAmount: target,
        initialAmount: initial,
        targetDate: 'Target: ${DateFormat('MMM yyyy').format(_targetDate)}',
        icon: _selectedPreset.icon,
        themeColor: _selectedPreset.color,
        gradientColors: _selectedPreset.gradient,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    final fieldFill =
        palette.isLight ? palette.inputBg : AppColors.cardSurfaceAlt;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            color: palette.glassCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.glassCardBorder, width: 1),
            boxShadow: [
              BoxShadow(color: palette.glassCardGlow, blurRadius: 28),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create New Goal',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Set a dynamic savings target',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: palette.textSecondary, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: palette.dangerSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.dangerBorder),
                    ),
                    child: Text(
                      _error!,
                      style: GoogleFonts.inter(fontSize: 12, color: palette.dangerTitle),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Goal Name
                _buildField(
                  palette: palette,
                  label: 'Goal Name',
                  child: TextField(
                    controller: _titleController,
                    style: TextStyle(color: palette.textPrimary, fontSize: 14),
                    decoration: _inputDecoration(palette: palette, fillColor: fieldFill, hint: 'e.g. Car Downpayment'),
                  ),
                ),
                const SizedBox(height: 14),

                // Target Amount
                _buildField(
                  palette: palette,
                  label: 'Target Amount (₱)',
                  child: TextField(
                    controller: _targetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    style: TextStyle(color: palette.textPrimary, fontSize: 14),
                    decoration: _inputDecoration(palette: palette, fillColor: fieldFill, hint: 'e.g. 50,000'),
                  ),
                ),
                const SizedBox(height: 14),

                // Initial Saved (Optional)
                _buildField(
                  palette: palette,
                  label: 'Already Saved (Optional ₱)',
                  child: TextField(
                    controller: _initialController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    style: TextStyle(color: palette.textPrimary, fontSize: 14),
                    decoration: _inputDecoration(palette: palette, fillColor: fieldFill, hint: 'e.g. 5,000 (0 if starting fresh)'),
                  ),
                ),
                const SizedBox(height: 14),

                // Target Date
                _buildField(
                  palette: palette,
                  label: 'Target Date',
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: fieldFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border, width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMMM yyyy').format(_targetDate),
                            style: TextStyle(color: palette.textPrimary, fontSize: 14),
                          ),
                          const Icon(Icons.calendar_today_outlined, color: AppColors.primaryOrange, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Category Preset Selector
                _buildField(
                  palette: palette,
                  label: 'Theme & Category',
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final preset in _presets)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    preset.icon,
                                    size: 16,
                                    color: _selectedPreset == preset ? Colors.black : preset.color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(preset.label),
                                ],
                              ),
                              selected: _selectedPreset == preset,
                              onSelected: (_) => setState(() => _selectedPreset = preset),
                              selectedColor: preset.color,
                              backgroundColor: fieldFill,
                              labelStyle: TextStyle(
                                color: _selectedPreset == preset ? Colors.black : palette.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              side: BorderSide(
                                color: _selectedPreset == preset ? preset.color : palette.border,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                      ],
                    ),
                  ),
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
                      '+ Create Goal',
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

  Widget _buildField({
    required BuckPalette palette,
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({
    required BuckPalette palette,
    required Color fillColor,
    required String hint,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: palette.textSecondary, fontSize: 14),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.border, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
      ),
    );
  }
}

class _PresetCategory {
  final String label;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  const _PresetCategory({
    required this.label,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}
