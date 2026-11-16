import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/settings_service.dart';
import '../widgets/settings_common.dart';

class _FeedbackCategory {
  final String title;
  final String description;
  final String iconPath;

  const _FeedbackCategory({
    required this.title,
    required this.description,
    required this.iconPath,
  });
}

/// Figma `Feedback` (`2498:798`).
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _categories = [
    _FeedbackCategory(
      title: 'Feature idea',
      description: "Something new you'd love to see",
      iconPath: 'assets/icons/settings_lightbulb.svg',
    ),
    _FeedbackCategory(
      title: 'Bug report',
      description: "Something isn't working right",
      iconPath: 'assets/icons/settings_bug.svg',
    ),
    _FeedbackCategory(
      title: 'Question issue',
      description: 'A problem with the question bank',
      iconPath: 'assets/icons/settings_circle_help.svg',
    ),
    _FeedbackCategory(
      title: 'General feedback',
      description: 'Anything else on your mind',
      iconPath: 'assets/icons/profile_panel_message_square.svg',
    ),
  ];

  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();
  String _selectedCategory = 'Feature idea';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    _detailsController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  String _formatLimit(int value) {
    if (value < 1000) return '$value';
    final thousands = value ~/ 1000;
    final rem = (value % 1000).toString().padLeft(3, '0');
    return '$thousands,$rem';
  }

  Future<void> _sendFeedback() async {
    final title = _titleController.text.trim();
    final details = _detailsController.text.trim();
    if (title.isEmpty || details.isEmpty) {
      showSettingsSnackBar(
        context,
        'Please enter a short summary and details.',
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await SettingsService.instance.submitFeedback(
        category: _selectedCategory,
        title: title,
        details: details,
      );
      if (!mounted) return;
      showSettingsSnackBar(
        context,
        'Thanks for your $_selectedCategory! Our team reads every note.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showSettingsSnackBar(
        context,
        'Unable to send feedback right now: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    return SettingsScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SettingsPageHeader(
            title: 'Feedback',
            subtitle:
                'Spotted a bug, have a feature idea, or want to flag a question? Tell us — the team reads every note.',
          ),
          const SizedBox(height: 24),
          Text(
            "What's this about?",
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 18 / 13,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ..._categories.map((cat) {
            final selected = _selectedCategory == cat.title;
            return InkWell(
              onTap: () => setState(() => _selectedCategory = cat.title),
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SvgPicture.asset(cat.iconPath, width: 19, height: 19),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.title,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 20 / 16,
                                color: selected
                                    ? SettingsColors.accentOrange
                                    : palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              cat.description,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SvgPicture.asset(
                        selected
                            ? 'assets/icons/settings_circle_check.svg'
                            : 'assets/icons/settings_circle.svg',
                        width: 18,
                        height: 18,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Title',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 20 / 16,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Text(
                '${_titleController.text.length} / 120',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('feedback_title_input'),
            controller: _titleController,
            maxLength: 120,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: palette.textPrimary,
            ),
            decoration: _inputDecoration('A short summary', palette),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Details',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 20 / 16,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Text(
                '${_formatLimit(_detailsController.text.length)} / 2,000',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('feedback_details_input'),
            controller: _detailsController,
            maxLength: 2000,
            minLines: 4,
            maxLines: 6,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: palette.textPrimary,
            ),
            decoration: _inputDecoration(
              "Tell us what you'd change, what happened, or what you'd like to see...",
              palette,
            ),
          ),
          const SizedBox(height: 16),
          SettingsOrangeButton(
            label: 'Send feedback',
            loading: _submitting,
            onTap: _sendFeedback,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, BuckPalette palette) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: palette.textSecondary,
      ),
      filled: true,
      fillColor: palette.inputBg,
      contentPadding: const EdgeInsets.all(14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: SettingsColors.accentOrange,
          width: 1.5,
        ),
      ),
    );
  }
}
