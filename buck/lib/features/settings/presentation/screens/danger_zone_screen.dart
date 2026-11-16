import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/settings_service.dart';
import '../widgets/settings_common.dart';
import '../widgets/settings_dialogs.dart';

/// Figma `Danger Zone` (`2498:863`).
class DangerZoneScreen extends StatefulWidget {
  final Future<void> Function() onDeletionConfirmed;
  final Future<void> Function()? onSubmitDeletion;

  const DangerZoneScreen({
    super.key,
    required this.onDeletionConfirmed,
    this.onSubmitDeletion,
  });

  @override
  State<DangerZoneScreen> createState() => _DangerZoneScreenState();
}

class _DangerZoneScreenState extends State<DangerZoneScreen> {
  final _confirmController = TextEditingController();
  bool _submitting = false;

  bool get _canRequestDeletion => _confirmController.text.trim() == 'DELETE';

  @override
  void initState() {
    super.initState();
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _requestDeletion() async {
    final confirmed = await showDeletionRequestConfirmationDialog(context);
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final submit =
          widget.onSubmitDeletion ?? SettingsService.instance.requestAccountDeletion;
      await submit();
      await widget.onDeletionConfirmed();
    } catch (e) {
      if (!mounted) return;
      showSettingsSnackBar(
        context,
        'Unable to submit account deletion request right now: $e',
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
            title: 'Danger Zone',
            subtitle: 'Sensitive actions. Take a moment.',
            largeTitle: true,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.dangerSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.dangerBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Delete account',
                  style: GoogleFonts.inter(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 32 / 25,
                    color: palette.dangerTitle,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Buck sends a confirmation email first. After confirmation, your account enters a 10-day recovery window before the scheduled job permanently erases it.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 22 / 16,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.dangerReminderBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: SvgPicture.asset(
                          'assets/icons/settings_clock_3.svg',
                          width: 18,
                          height: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can recover your account during those 10 days. After that, deletion is permanent.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 22 / 15,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Type DELETE to confirm',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('danger_zone_delete_input'),
                  controller: _confirmController,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: palette.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: palette.textSecondary,
                    ),
                    filled: true,
                    fillColor: palette.scaffoldDarkBg,
                    contentPadding: const EdgeInsets.all(14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: palette.dangerBorder,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: palette.dangerTitle,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SettingsRedButton(
                  key: const Key('danger_zone_request_button'),
                  label: 'Request deletion',
                  height: 52,
                  loading: _submitting,
                  onTap: _canRequestDeletion ? _requestDeletion : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
