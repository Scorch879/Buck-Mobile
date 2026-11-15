import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/settings_service.dart';
import '../widgets/settings_common.dart';

/// Figma `Security` (`2498:702`).
class SecurityScreen extends StatelessWidget {
  final BuckSettingsContext settingsContext;

  const SecurityScreen({super.key, required this.settingsContext});

  @override
  Widget build(BuildContext context) {
    final provider = settingsContext.providerName;
    final emailHeadline = settingsContext.isGoogleManaged
        ? 'Email is managed by Google.'
        : 'Signed in as ${settingsContext.email}.';
    final emailDescription = settingsContext.isGoogleManaged
        ? 'Sign in with Google controls the account email. Buck keeps your dashboard data tied to the authenticated Google account.'
        : 'Your account email identifies your Buck session and syncs your budgets, goals, and wallets securely.';
    final passwordHeadline = settingsContext.isGoogleManaged
        ? 'Password is managed by Google.'
        : 'Managed via Buck authentication.';
    final passwordDescription = settingsContext.isGoogleManaged
        ? 'Use your Google account settings to manage password and sign-in security for this Buck account.'
        : 'Use the Forgot Password flow on the sign-in screen whenever you want to reset your password.';

    return SettingsScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SettingsPageHeader(
            title: 'Security',
            subtitle: 'Your account, protected.',
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/profile_panel_shield_check.svg',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Protected by $provider',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 20 / 14,
                          color: SettingsColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settingsContext.isGoogleManaged
                            ? 'Your sign-in security is managed in your Google account.'
                            : 'Your session is protected through Buck authentication.',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 20 / 15,
                          color: SettingsColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ManagedSecurityBlock(
            iconPath: 'assets/icons/settings_mail.svg',
            eyebrow: 'Email address',
            headline: emailHeadline,
            description: emailDescription,
          ),
          const SizedBox(height: 12),
          const Divider(
            height: 1,
            thickness: 1,
            color: SettingsColors.border,
          ),
          const SizedBox(height: 12),
          _ManagedSecurityBlock(
            iconPath: 'assets/icons/settings_lock_keyhole.svg',
            eyebrow: 'Password',
            headline: passwordHeadline,
            description: passwordDescription,
          ),
          const SizedBox(height: 48),
          Text(
            'Connected apps',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 20 / 14,
              color: SettingsColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Connected apps can only read your Buck data.',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 20 / 15,
              color: SettingsColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SvgPicture.asset(
                  'assets/icons/settings_unplug.svg',
                  width: 26,
                  height: 26,
                ),
                const SizedBox(height: 8),
                Text(
                  'No apps connected',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                    color: SettingsColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Apps you allow to read your Buck data will show here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 20 / 15,
                    color: SettingsColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SvgPicture.asset(
                  'assets/icons/settings_info.svg',
                  width: 16,
                  height: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'If you turn on two-factor authentication, reconnect your apps so they keep working.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 20 / 15,
                    color: SettingsColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManagedSecurityBlock extends StatelessWidget {
  final String iconPath;
  final String eyebrow;
  final String headline;
  final String description;

  const _ManagedSecurityBlock({
    required this.iconPath,
    required this.eyebrow,
    required this.headline,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(iconPath, width: 17, height: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                eyebrow,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 18 / 13,
                  color: SettingsColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          headline,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 20 / 14,
            color: SettingsColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 20 / 15,
            color: SettingsColors.textMuted,
          ),
        ),
      ],
    );
  }
}
