import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/settings_service.dart';
import '../widgets/settings_common.dart';
import 'appearance_screen.dart';
import 'danger_zone_screen.dart';
import 'feedback_screen.dart';
import 'profile_account_screen.dart';
import 'security_screen.dart';

/// Figma `Settings Menu` (`2498:609`).
class SettingsMenuScreen extends StatefulWidget {
  final BuckSettingsContext settingsContext;
  final Future<void> Function() onSignOut;
  final VoidCallback? onProfileUpdated;

  const SettingsMenuScreen({
    super.key,
    required this.settingsContext,
    required this.onSignOut,
    this.onProfileUpdated,
  });

  @override
  State<SettingsMenuScreen> createState() => _SettingsMenuScreenState();
}

class _SettingsMenuScreenState extends State<SettingsMenuScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _pushScreen(Widget screen) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _handleDeletionConfirmed() async {
    if (!mounted) return;
    showSettingsSnackBar(
      context,
      'Account deletion scheduled with a 10-day recovery window.',
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
    await widget.onSignOut();
  }

  bool _matches(String title, String subtitle) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return title.toLowerCase().contains(query) ||
        subtitle.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    final showProfile = _matches(
      'Profile & Account',
      'Your details, all in one place.',
    );
    final showSecurity = _matches(
      'Security',
      'Password & account protection',
    );
    final showAppearance = _matches('Appearance', 'Make it look like you');
    final showFeedback = _matches('Feedback', 'Help shape what comes next');
    final showDangerZone = _matches('Danger Zone', 'Sensitive account actions');
    final hasAnyPreference =
        showSecurity || showAppearance || showFeedback || showDangerZone;

    return SettingsScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SettingsPageHeader(
            title: 'Settings',
            subtitle: 'Make yourself at home.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('settings_search_input'),
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 22 / 16,
              color: palette.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search settings',
              hintStyle: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 22 / 16,
                color: palette.textSecondary,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 10),
                child: SvgPicture.asset(
                  'assets/icons/settings_search.svg',
                  width: 20,
                  height: 20,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 46,
                minHeight: 44,
              ),
              filled: true,
              fillColor: palette.inputBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 36),
          if (showProfile) ...[
            Text(
              'Your account',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 22 / 17,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _SettingsMenuRow(
              iconPath: 'assets/icons/profile_panel_user_round.svg',
              title: 'Profile & Account',
              subtitle: 'Your details, all in one place.',
              titleFontSize: 17,
              onTap: () => _pushScreen(
                ProfileAccountScreen(
                  settingsContext: widget.settingsContext,
                  onProfileUpdated: widget.onProfileUpdated,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (hasAnyPreference) ...[
            Text(
              'Preferences',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 22 / 17,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (showSecurity)
              _SettingsMenuRow(
                iconPath: 'assets/icons/profile_panel_shield_check.svg',
                title: 'Security',
                subtitle: 'Password & account protection',
                onTap: () => _pushScreen(
                  SecurityScreen(settingsContext: widget.settingsContext),
                ),
              ),
            if (showAppearance)
              _SettingsMenuRow(
                iconPath: 'assets/icons/profile_panel_palette.svg',
                title: 'Appearance',
                subtitle: 'Make it look like you',
                onTap: () => _pushScreen(const AppearanceScreen()),
              ),
            if (showFeedback)
              _SettingsMenuRow(
                iconPath: 'assets/icons/profile_panel_message_square.svg',
                title: 'Feedback',
                subtitle: 'Help shape what comes next',
                onTap: () => _pushScreen(const FeedbackScreen()),
              ),
            if (showDangerZone)
              _SettingsMenuRow(
                iconPath: 'assets/icons/profile_panel_triangle_alert.svg',
                title: 'Danger Zone',
                subtitle: 'Sensitive account actions',
                titleColor: palette.dangerTitle,
                iconColorFilter: ColorFilter.mode(
                  palette.dangerTitle,
                  BlendMode.srcIn,
                ),
                onTap: () => _pushScreen(
                  DangerZoneScreen(
                    onDeletionConfirmed: _handleDeletionConfirmed,
                  ),
                ),
              ),
          ],
          if (!showProfile && !hasAnyPreference)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'No matching settings found.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: palette.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsMenuRow extends StatelessWidget {
  final String iconPath;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final ColorFilter? iconColorFilter;
  final double titleFontSize;
  final VoidCallback onTap;

  const _SettingsMenuRow({
    required this.iconPath,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
    this.iconColorFilter,
    this.titleFontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 80,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                height: 44,
                child: Center(
                  child: SvgPicture.asset(
                    iconPath,
                    width: 20,
                    height: 20,
                    colorFilter: iconColorFilter,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        height: 22 / titleFontSize,
                        color: titleColor ?? palette.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 22 / 15,
                        color: palette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SvgPicture.asset(
                'assets/icons/settings_chevron_right.svg',
                width: 20,
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
