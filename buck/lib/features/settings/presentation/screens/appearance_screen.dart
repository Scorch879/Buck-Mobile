import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/settings_service.dart';
import '../widgets/settings_common.dart';

/// Figma `Appearance` (`2498:751`).
class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  @override
  void initState() {
    super.initState();
    SettingsService.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    return SettingsScaffold(
      child: ValueListenableBuilder<String>(
        valueListenable: SettingsService.instance.selectedTheme,
        builder: (context, selectedTheme, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SettingsPageHeader(
                title: 'Appearance',
                subtitle: 'A look that feels like you.',
                largeTitle: true,
              ),
              const SizedBox(height: 18),
              Text(
                'Theme',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 18 / 13,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _ThemeOptionCard(
                key: const Key('appearance_theme_light'),
                label: 'Light',
                iconPath: 'assets/icons/settings_sun.svg',
                selected: selectedTheme == 'Light',
                previewBg: const Color(0xFFF5ECE3),
                previewHeading: const Color(0xFFD8C6B6),
                previewCard: const Color(0xFFD8C6B6),
                previewLine: const Color(0xFFD8C6B6),
                onTap: () => SettingsService.instance.setTheme('Light'),
              ),
              const SizedBox(height: 16),
              _ThemeOptionCard(
                key: const Key('appearance_theme_dark'),
                label: 'Dark',
                iconPath: 'assets/icons/settings_moon.svg',
                selected: selectedTheme == 'Dark',
                previewBg: SettingsColors.inputBg,
                previewHeading: SettingsColors.textMuted,
                previewCard: SettingsColors.scaffoldBg,
                previewLine: SettingsColors.border,
                onTap: () => SettingsService.instance.setTheme('Dark'),
              ),
              const SizedBox(height: 20),
              Text(
                '$selectedTheme is currently selected.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 22 / 15,
                  color: palette.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String label;
  final String iconPath;
  final bool selected;
  final Color previewBg;
  final Color previewHeading;
  final Color previewCard;
  final Color previewLine;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    super.key,
    required this.label,
    required this.iconPath,
    required this.selected,
    required this.previewBg,
    required this.previewHeading,
    required this.previewCard,
    required this.previewLine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    return Material(
      color: selected ? palette.inputBg : palette.cardSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? SettingsColors.accentOrange
                  : palette.border,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 136,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: previewBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: previewHeading,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: previewCard,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              color: previewLine,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 26,
                          height: 7,
                          decoration: BoxDecoration(
                            color: SettingsColors.accentOrange,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SvgPicture.asset(iconPath, width: 16, height: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 20 / 16,
                        color: BuckPalette.of(context).textPrimary,
                      ),
                    ),
                  ),
                  SvgPicture.asset(
                    selected
                        ? 'assets/icons/settings_circle_check.svg'
                        : 'assets/icons/settings_circle.svg',
                    width: 18,
                    height: 18,
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
