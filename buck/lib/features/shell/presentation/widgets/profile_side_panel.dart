import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';

/// Destination actions available inside [ProfileSidePanel].
enum ProfilePanelDestination {
  profileAccount,
  security,
  appearance,
  feedback,
  settingsMenu,
  dangerZone,
}

/// Shows the Figma "Profile Side Panel/Overlay" (`2510:648`) sliding in from
/// the left edge on top of the active shell screen.
Future<void> showProfileSidePanel({
  required BuildContext context,
  required String displayName,
  required String email,
  required String connectionLabel,
  required Future<void> Function() onSignOut,
  void Function(String message)? onShowMessage,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close profile menu',
    barrierColor: Colors.black.withValues(alpha: 0.58),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _ProfileSidePanelOverlay(
        displayName: displayName,
        email: email,
        connectionLabel: connectionLabel,
        onSignOut: onSignOut,
        onShowMessage: onShowMessage,
      );
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1.0, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class _ProfileSidePanelOverlay extends StatefulWidget {
  final String displayName;
  final String email;
  final String connectionLabel;
  final Future<void> Function() onSignOut;
  final void Function(String message)? onShowMessage;

  const _ProfileSidePanelOverlay({
    required this.displayName,
    required this.email,
    required this.connectionLabel,
    required this.onSignOut,
    this.onShowMessage,
  });

  @override
  State<_ProfileSidePanelOverlay> createState() =>
      _ProfileSidePanelOverlayState();
}

class _ProfileSidePanelOverlayState extends State<_ProfileSidePanelOverlay> {
  static const _panelCardBg = Color(0xFF392519);
  static const _panelTileBg = Color(0xFF241710);
  static const _panelBorder = Color(0xFF483126);

  bool _accountExpanded = false;
  bool _showMoreExpanded = false;
  bool _settingsExpanded = false;
  bool _dangerExpanded = false;

  void _closeAndNotify(String message) {
    Navigator.of(context).pop();
    widget.onShowMessage?.call(message);
  }

  Future<void> _confirmAndSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _SignOutConfirmDialog(),
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop();
    await widget.onSignOut();
  }

  Future<void> _openSectionSheet(ProfilePanelDestination destination) async {
    final action = await showModalBottomSheet<_DetailSheetAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ProfileDetailSheet(
          destination: destination,
          displayName: widget.displayName,
          email: widget.email,
          connectionLabel: widget.connectionLabel,
        );
      },
    );

    if (!mounted || action == null) return;
    switch (action.type) {
      case _DetailActionType.signOut:
        await _confirmAndSignOut();
        break;
      case _DetailActionType.message:
        if (action.message != null) {
          _closeAndNotify(action.message!);
        }
        break;
      case _DetailActionType.navigate:
        if (action.nextDestination != null) {
          await _openSectionSheet(action.nextDestination!);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topInset = AppLayout.topSafeInset(context);
    final bottomInset = AppLayout.bottomSafeInset(context);
    final panelWidth = math.min(378.0, size.width * 0.88);

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: Container(
          key: const Key('profile_side_panel'),
          width: panelWidth,
          height: size.height,
          decoration: const BoxDecoration(
            color: AppColors.navBarBg,
            border: Border(
              right: BorderSide(color: AppColors.glassCardBorder, width: 1),
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              14,
              math.max(48.0, topInset + 16.0),
              14,
              math.max(24.0, bottomInset + 16.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileAccountCard(
                  displayName: widget.displayName,
                  email: widget.email,
                  connectionLabel: widget.connectionLabel,
                  expanded: _accountExpanded,
                  onToggleExpand: () {
                    setState(() => _accountExpanded = !_accountExpanded);
                  },
                  onManageAccount: () =>
                      _openSectionSheet(ProfilePanelDestination.profileAccount),
                  onSignOutTap: _confirmAndSignOut,
                ),
                const SizedBox(height: 20),
                _ShortcutsSection(
                  onSecurityTap: () =>
                      _openSectionSheet(ProfilePanelDestination.security),
                  onAppearanceTap: () =>
                      _openSectionSheet(ProfilePanelDestination.appearance),
                  onFeedbackTap: () =>
                      _openSectionSheet(ProfilePanelDestination.feedback),
                ),
                const SizedBox(height: 20),
                _NavigationTileGrid(
                  onProfileTap: () =>
                      _openSectionSheet(ProfilePanelDestination.profileAccount),
                  onSecurityTap: () =>
                      _openSectionSheet(ProfilePanelDestination.security),
                  onAppearanceTap: () =>
                      _openSectionSheet(ProfilePanelDestination.appearance),
                  onFeedbackTap: () =>
                      _openSectionSheet(ProfilePanelDestination.feedback),
                ),
                if (_showMoreExpanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _panelTileBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _panelBorder, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Quick Session & Preferences',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ExpandedActionRow(
                          iconPath: 'assets/icons/profile_panel_settings.svg',
                          label: 'Open Full Settings',
                          onTap: () => _openSectionSheet(
                            ProfilePanelDestination.settingsMenu,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ExpandedActionRow(
                          iconPath: 'assets/icons/profile_panel_log_out.svg',
                          label: 'Sign out of Buck',
                          labelColor: const Color(0xFFFF9B91),
                          onTap: _confirmAndSignOut,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _SeeMoreButton(
                  expanded: _showMoreExpanded,
                  onTap: () {
                    setState(() => _showMoreExpanded = !_showMoreExpanded);
                  },
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: _panelBorder, width: 1),
                      bottom: BorderSide(color: _panelBorder, width: 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AccordionSectionRow(
                        key: const Key('panel_settings_menu_row'),
                        iconPath: 'assets/icons/profile_panel_settings.svg',
                        title: 'Settings Menu',
                        expanded: _settingsExpanded,
                        onTap: () {
                          setState(() {
                            _settingsExpanded = !_settingsExpanded;
                          });
                        },
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _panelCardBg.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _panelBorder, width: 1),
                            ),
                            child: Column(
                              children: [
                                _ExpandedActionRow(
                                  iconPath:
                                      'assets/icons/profile_panel_user_round.svg',
                                  label: 'Profile & Account',
                                  onTap: () => _openSectionSheet(
                                    ProfilePanelDestination.profileAccount,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _ExpandedActionRow(
                                  iconPath:
                                      'assets/icons/profile_panel_shield_check.svg',
                                  label: 'Security & Connected Apps',
                                  onTap: () => _openSectionSheet(
                                    ProfilePanelDestination.security,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _ExpandedActionRow(
                                  iconPath:
                                      'assets/icons/profile_panel_palette.svg',
                                  label: 'Appearance & Theme',
                                  onTap: () => _openSectionSheet(
                                    ProfilePanelDestination.appearance,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _ExpandedActionRow(
                                  iconPath:
                                      'assets/icons/profile_panel_settings.svg',
                                  label: 'All Settings',
                                  onTap: () => _openSectionSheet(
                                    ProfilePanelDestination.settingsMenu,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        crossFadeState: _settingsExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 180),
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: _panelBorder,
                      ),
                      _AccordionSectionRow(
                        key: const Key('panel_danger_zone_row'),
                        iconPath:
                            'assets/icons/profile_panel_triangle_alert.svg',
                        title: 'Danger Zone',
                        expanded: _dangerExpanded,
                        onTap: () {
                          setState(() {
                            _dangerExpanded = !_dangerExpanded;
                          });
                        },
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SignOutGradientButton(onTap: _confirmAndSignOut),
                              const SizedBox(height: 8),
                              _ExpandedActionRow(
                                iconPath:
                                    'assets/icons/profile_panel_triangle_alert.svg',
                                label: 'Account deletion & sensitive actions',
                                labelColor: const Color(0xFFFF9B91),
                                onTap: () => _openSectionSheet(
                                  ProfilePanelDestination.dangerZone,
                                ),
                              ),
                            ],
                          ),
                        ),
                        crossFadeState: _dangerExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 180),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAccountCard extends StatelessWidget {
  final String displayName;
  final String email;
  final String connectionLabel;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onManageAccount;
  final VoidCallback onSignOutTap;

  const _ProfileAccountCard({
    required this.displayName,
    required this.email,
    required this.connectionLabel,
    required this.expanded,
    required this.onToggleExpand,
    required this.onManageAccount,
    required this.onSignOutTap,
  });

  static const _cardBg = Color(0xFF392519);
  static const _borderColor = Color(0xFF483126);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggleExpand,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: _borderColor, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/icons/profile_panel_user_round.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 20 / 16,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 18 / 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.inputBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: AnimatedRotation(
                      turns: expanded ? -0.25 : 0.25,
                      duration: const Duration(milliseconds: 180),
                      child: SvgPicture.asset(
                        'assets/icons/profile_panel_chevron_small.svg',
                        width: 16,
                        height: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1, thickness: 1, color: _borderColor),
                  const SizedBox(height: 10),
                  _ExpandedActionRow(
                    iconPath: 'assets/icons/profile_panel_user_round.svg',
                    label: 'Manage Profile & Account',
                    onTap: onManageAccount,
                  ),
                  const SizedBox(height: 8),
                  _SignOutGradientButton(onTap: onSignOutTap),
                ],
              ),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _borderColor, width: 1)),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/profile_panel_status_dot.svg',
                  width: 8,
                  height: 8,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    connectionLabel,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 18 / 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutsSection extends StatelessWidget {
  final VoidCallback onSecurityTap;
  final VoidCallback onAppearanceTap;
  final VoidCallback onFeedbackTap;

  const _ShortcutsSection({
    required this.onSecurityTap,
    required this.onAppearanceTap,
    required this.onFeedbackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your shortcuts',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 20 / 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ShortcutChip(
                key: const Key('shortcut_security'),
                iconPath: 'assets/icons/profile_panel_shield_check.svg',
                label: 'Security',
                onTap: onSecurityTap,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _ShortcutChip(
                key: const Key('shortcut_appearance'),
                iconPath: 'assets/icons/profile_panel_palette.svg',
                label: 'Appearance',
                onTap: onAppearanceTap,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _ShortcutChip(
                key: const Key('shortcut_feedback'),
                iconPath: 'assets/icons/profile_panel_message_square.svg',
                label: 'Feedback',
                onTap: onFeedbackTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  final String iconPath;
  final String label;
  final VoidCallback onTap;

  const _ShortcutChip({
    super.key,
    required this.iconPath,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF392519),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(iconPath, width: 26, height: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 18 / 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _NavigationTileGrid extends StatelessWidget {
  final VoidCallback onProfileTap;
  final VoidCallback onSecurityTap;
  final VoidCallback onAppearanceTap;
  final VoidCallback onFeedbackTap;

  const _NavigationTileGrid({
    required this.onProfileTap,
    required this.onSecurityTap,
    required this.onAppearanceTap,
    required this.onFeedbackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _NavigationTile(
                key: const Key('tile_profile_account'),
                iconPath: 'assets/icons/profile_panel_user_round.svg',
                label: 'Profile & Account',
                onTap: onProfileTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NavigationTile(
                key: const Key('tile_security'),
                iconPath: 'assets/icons/profile_panel_shield_check.svg',
                label: 'Security',
                onTap: onSecurityTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NavigationTile(
                key: const Key('tile_appearance'),
                iconPath: 'assets/icons/profile_panel_palette.svg',
                label: 'Appearance',
                onTap: onAppearanceTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NavigationTile(
                key: const Key('tile_feedback'),
                iconPath: 'assets/icons/profile_panel_message_square.svg',
                label: 'Feedback',
                onTap: onFeedbackTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavigationTile extends StatelessWidget {
  final String iconPath;
  final String label;
  final VoidCallback onTap;

  const _NavigationTile({
    super.key,
    required this.iconPath,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF241710),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 92,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF483126), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(iconPath, width: 24, height: 24),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 20 / 14,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeeMoreButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _SeeMoreButton({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inputBg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          child: Text(
            expanded ? 'See less' : 'See more',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 24 / 18,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccordionSectionRow extends StatelessWidget {
  final String iconPath;
  final String title;
  final bool expanded;
  final VoidCallback onTap;

  const _AccordionSectionRow({
    super.key,
    required this.iconPath,
    required this.title,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              SvgPicture.asset(iconPath, width: 24, height: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 20 / 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: AnimatedRotation(
                    turns: expanded ? -0.25 : 0.25,
                    duration: const Duration(milliseconds: 180),
                    child: SvgPicture.asset(
                      'assets/icons/profile_panel_chevron_down.svg',
                      width: 18,
                      height: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedActionRow extends StatelessWidget {
  final String iconPath;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  const _ExpandedActionRow({
    required this.iconPath,
    required this.label,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navBarBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SvgPicture.asset(iconPath, width: 18, height: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: labelColor ?? AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutGradientButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SignOutGradientButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFAC2530),
                Color(0xFFC42F3A),
                Color(0xFFD13945),
              ],
            ),
          ),
          child: Center(
            child: Text(
              'Sign out',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 20 / 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _DetailActionType { signOut, message, navigate }

class _DetailSheetAction {
  final _DetailActionType type;
  final String? message;
  final ProfilePanelDestination? nextDestination;

  const _DetailSheetAction.signOut()
      : type = _DetailActionType.signOut,
        message = null,
        nextDestination = null;

  const _DetailSheetAction.message(this.message)
      : type = _DetailActionType.message,
        nextDestination = null;

  const _DetailSheetAction.navigate(this.nextDestination)
      : type = _DetailActionType.navigate,
        message = null;
}

class _ProfileDetailSheet extends StatefulWidget {
  final ProfilePanelDestination destination;
  final String displayName;
  final String email;
  final String connectionLabel;

  const _ProfileDetailSheet({
    required this.destination,
    required this.displayName,
    required this.email,
    required this.connectionLabel,
  });

  @override
  State<_ProfileDetailSheet> createState() => _ProfileDetailSheetState();
}

class _ProfileDetailSheetState extends State<_ProfileDetailSheet> {
  final _searchController = TextEditingController();
  final _feedbackTitleController = TextEditingController();
  final _feedbackDetailsController = TextEditingController();
  final _deleteConfirmController = TextEditingController();

  String _selectedFeedbackCategory = 'Feature idea';
  String _selectedTheme = 'Dark';

  @override
  void dispose() {
    _searchController.dispose();
    _feedbackTitleController.dispose();
    _feedbackDetailsController.dispose();
    _deleteConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      margin: EdgeInsets.only(top: 64),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.navBarBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.glassCardBorder, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF241710),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF483126)),
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/icons/profile_panel_arrow_left.svg',
                      width: 20,
                      height: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _sheetTitle(widget.destination),
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _sheetSubtitle(widget.destination),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  String _sheetTitle(ProfilePanelDestination d) {
    switch (d) {
      case ProfilePanelDestination.profileAccount:
        return 'Profile & Account';
      case ProfilePanelDestination.security:
        return 'Security';
      case ProfilePanelDestination.appearance:
        return 'Appearance';
      case ProfilePanelDestination.feedback:
        return 'Feedback';
      case ProfilePanelDestination.settingsMenu:
        return 'Settings';
      case ProfilePanelDestination.dangerZone:
        return 'Danger Zone';
    }
  }

  String _sheetSubtitle(ProfilePanelDestination d) {
    switch (d) {
      case ProfilePanelDestination.profileAccount:
        return 'Your details, your personal touch.';
      case ProfilePanelDestination.security:
        return 'Your account, protected.';
      case ProfilePanelDestination.appearance:
        return 'A look that feels like you.';
      case ProfilePanelDestination.feedback:
        return 'Spotted a bug or have an idea? Tell us — we read every note.';
      case ProfilePanelDestination.settingsMenu:
        return 'Make yourself at home.';
      case ProfilePanelDestination.dangerZone:
        return 'Sensitive actions. Take a moment.';
    }
  }

  Widget _buildBody(BuildContext context) {
    switch (widget.destination) {
      case ProfilePanelDestination.profileAccount:
        return _buildProfileAccount();
      case ProfilePanelDestination.security:
        return _buildSecurity();
      case ProfilePanelDestination.appearance:
        return _buildAppearance();
      case ProfilePanelDestination.feedback:
        return _buildFeedback();
      case ProfilePanelDestination.settingsMenu:
        return _buildSettingsMenu();
      case ProfilePanelDestination.dangerZone:
        return _buildDangerZone();
    }
  }

  Widget _buildProfileAccount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF241710),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF483126)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF483126)),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/icons/profile_panel_user_round.svg',
                  width: 26,
                  height: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.email,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.connectionLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SignOutGradientButton(
          onTap: () =>
              Navigator.of(context).pop(const _DetailSheetAction.signOut()),
        ),
      ],
    );
  }

  Widget _buildSecurity() {
    final isGoogle = widget.connectionLabel.toLowerCase().contains('google');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoCard(
          icon: Icons.verified_user_outlined,
          title: isGoogle ? 'Protected by Google' : 'Account Protection',
          subtitle: isGoogle
              ? 'Your sign-in security is managed in your Google account.'
              : 'Your session is authenticated through Supabase Auth.',
        ),
        const SizedBox(height: 10),
        _InfoCard(
          icon: Icons.mail_outline_rounded,
          title: 'Email address',
          subtitle: widget.email,
        ),
        const SizedBox(height: 10),
        _InfoCard(
          icon: Icons.lock_outline_rounded,
          title: 'Password',
          subtitle: isGoogle
              ? 'Password is managed by Google. Use your Google account settings to update credentials.'
              : 'Use Reset Password from the sign-in screen whenever you want to rotate your password.',
        ),
      ],
    );
  }

  Widget _buildAppearance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Theme',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ThemeOptionCard(
                label: 'Light',
                icon: Icons.wb_sunny_outlined,
                selected: _selectedTheme == 'Light',
                onTap: () => setState(() => _selectedTheme = 'Light'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ThemeOptionCard(
                label: 'Dark',
                icon: Icons.nightlight_round,
                selected: _selectedTheme == 'Dark',
                onTap: () => setState(() => _selectedTheme = 'Dark'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '$_selectedTheme is currently selected.${_selectedTheme == 'Light' ? ' Buck Amber Dark remains default across mobile shell screens.' : ''}',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFeedback() {
    const categories = [
      'Feature idea',
      'Bug report',
      'Question issue',
      'General feedback',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((cat) {
            final selected = _selectedFeedbackCategory == cat;
            return ChoiceChip(
              label: Text(cat),
              selected: selected,
              onSelected: (_) => setState(() => _selectedFeedbackCategory = cat),
              selectedColor: AppColors.primaryOrange,
              backgroundColor: const Color(0xFF241710),
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.black : AppColors.textPrimary,
              ),
              side: BorderSide(
                color: selected
                    ? AppColors.primaryOrange
                    : const Color(0xFF483126),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _feedbackTitleController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'A short summary',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF483126)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _feedbackDetailsController,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Tell us what you would change or like to see...',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF483126)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final title = _feedbackTitleController.text.trim();
              Navigator.of(context).pop(
                _DetailSheetAction.message(
                  title.isEmpty
                      ? 'Thanks for sharing $_selectedFeedbackCategory feedback!'
                      : 'Feedback sent: "$title"',
                ),
              );
            },
            child: const Text(
              'Send feedback',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsMenu() {
    final query = _searchController.text.trim().toLowerCase();
    final entries = [
      (
        title: 'Profile & Account',
        subtitle: 'Your details, all in one place.',
        iconPath: 'assets/icons/profile_panel_user_round.svg',
        dest: ProfilePanelDestination.profileAccount,
      ),
      (
        title: 'Security',
        subtitle: 'Password & account protection',
        iconPath: 'assets/icons/profile_panel_shield_check.svg',
        dest: ProfilePanelDestination.security,
      ),
      (
        title: 'Appearance',
        subtitle: 'Make it look like you',
        iconPath: 'assets/icons/profile_panel_palette.svg',
        dest: ProfilePanelDestination.appearance,
      ),
      (
        title: 'Feedback',
        subtitle: 'Help shape what comes next',
        iconPath: 'assets/icons/profile_panel_message_square.svg',
        dest: ProfilePanelDestination.feedback,
      ),
      (
        title: 'Danger Zone',
        subtitle: 'Sensitive account actions',
        iconPath: 'assets/icons/profile_panel_triangle_alert.svg',
        dest: ProfilePanelDestination.dangerZone,
      ),
    ].where((entry) {
      if (query.isEmpty) return true;
      return entry.title.toLowerCase().contains(query) ||
          entry.subtitle.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary,
            ),
            hintText: 'Search settings',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.inputBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...entries.map((entry) {
          final isDanger = entry.dest == ProfilePanelDestination.dangerZone;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: SvgPicture.asset(entry.iconPath, width: 20, height: 20),
            title: Text(
              entry.title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDanger
                    ? const Color(0xFFFF9B91)
                    : AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              entry.subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
            onTap: () =>
                Navigator.of(context).pop(_DetailSheetAction.navigate(entry.dest)),
          );
        }),
        const SizedBox(height: 12),
        _SignOutGradientButton(
          onTap: () =>
              Navigator.of(context).pop(const _DetailSheetAction.signOut()),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    final canRequest = _deleteConfirmController.text.trim() == 'DELETE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF241710),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF6B2A2E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Delete account',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFF9B91),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Buck sends a confirmation email first. After confirmation, your account enters a 10-day recovery window before permanent deletion.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _deleteConfirmController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Type DELETE to confirm',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  hintText: 'DELETE',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canRequest
                        ? const Color(0xFFC42F3A)
                        : const Color(0xFF4A2528),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: canRequest
                      ? () => Navigator.of(context).pop(
                            const _DetailSheetAction.message(
                              'Account deletion requests are handled via support@buck.app for safety.',
                            ),
                          )
                      : null,
                  child: const Text(
                    'Request deletion',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SignOutGradientButton(
          onTap: () =>
              Navigator.of(context).pop(const _DetailSheetAction.signOut()),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF241710),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF483126)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.primaryOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF241710),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primaryOrange
                : const Color(0xFF483126),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? AppColors.primaryOrange
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignOutConfirmDialog extends StatelessWidget {
  const _SignOutConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF241710),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF483126)),
      ),
      icon: SvgPicture.asset(
        'assets/icons/profile_panel_triangle_alert.svg',
        width: 28,
        height: 28,
      ),
      title: Text(
        'Sign out of Buck?',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      content: Text(
        "You'll need to sign in again to access your account. Your saved data will stay in your account.",
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: Color(0xFF483126)),
          ),
          child: const Text('Stay signed in'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC42F3A),
            foregroundColor: Colors.white,
          ),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
