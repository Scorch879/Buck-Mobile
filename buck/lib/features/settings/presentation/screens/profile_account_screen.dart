import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/settings_service.dart';
import '../widgets/settings_common.dart';

/// Figma `Profile & Account` (`2498:663`).
class ProfileAccountScreen extends StatefulWidget {
  final BuckSettingsContext settingsContext;
  final VoidCallback? onProfileUpdated;

  const ProfileAccountScreen({
    super.key,
    required this.settingsContext,
    this.onProfileUpdated,
  });

  @override
  State<ProfileAccountScreen> createState() => _ProfileAccountScreenState();
}

class _ProfileAccountScreenState extends State<ProfileAccountScreen> {
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.settingsContext.displayName,
    );
    SettingsService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await SettingsService.instance.setCustomAvatar(bytes);
      if (mounted) {
        showSettingsSnackBar(context, 'Profile picture updated.');
      }
    } catch (_) {
      if (mounted) {
        showSettingsSnackBar(
          context,
          'Unable to select an image right now.',
          isError: true,
        );
      }
    }
  }

  Future<void> _removeAvatar() async {
    await SettingsService.instance.setCustomAvatar(null);
    if (mounted) {
      showSettingsSnackBar(context, 'Profile picture removed.');
    }
  }

  Future<void> _saveChanges() async {
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) {
      showSettingsSnackBar(
        context,
        'Display name cannot be empty.',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await SettingsService.instance.updateDisplayName(trimmed);
      widget.onProfileUpdated?.call();
      if (!mounted) return;
      showSettingsSnackBar(context, 'Profile updated.');
    } catch (e) {
      if (!mounted) return;
      showSettingsSnackBar(
        context,
        'Failed to save changes. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
            title: 'Profile & Account',
            subtitle: 'Your details, your personal touch.',
            largeTitle: true,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.cardSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: SettingsColors.accentOrange,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ValueListenableBuilder(
                      valueListenable:
                          SettingsService.instance.customAvatarBytes,
                      builder: (context, bytes, _) {
                        return Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: palette.inputBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: SettingsColors.accentOrange,
                              width: 1,
                            ),
                            image: bytes != null
                                ? DecorationImage(
                                    image: MemoryImage(bytes),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: bytes == null
                              ? SvgPicture.asset(
                                  'assets/icons/profile_panel_user_round.svg',
                                  width: 28,
                                  height: 28,
                                )
                              : null,
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.settingsContext.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 32 / 20,
                              color: palette.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.settingsContext.email,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 22 / 15,
                              color: palette.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.settingsContext.connectionLabel,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 18 / 13,
                              color: palette.textAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _AvatarActionButton(
                        label: 'Upload avatar',
                        onTap: _pickAvatar,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _AvatarActionButton(
                        label: 'Remove',
                        onTap: _removeAvatar,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Choose a profile picture to make Buck yours.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 22 / 15,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.cardSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Display name',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('profile_display_name_input'),
                  controller: _nameController,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 22 / 16,
                    color: palette.textPrimary,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: palette.inputBg,
                    contentPadding: const EdgeInsets.all(14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: palette.border,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: SettingsColors.accentOrange,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SettingsOrangeButton(
            label: 'Save changes',
            loading: _saving,
            onTap: _saveChanges,
          ),
        ],
      ),
    );
  }
}

class _AvatarActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AvatarActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    return Material(
      color: palette.inputBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border, width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 20 / 16,
              color: palette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
