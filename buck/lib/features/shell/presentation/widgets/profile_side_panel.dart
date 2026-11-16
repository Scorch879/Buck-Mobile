import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../settings/data/settings_service.dart';
import '../../../settings/presentation/screens/appearance_screen.dart';
import '../../../settings/presentation/screens/danger_zone_screen.dart';
import '../../../settings/presentation/screens/feedback_screen.dart';
import '../../../settings/presentation/screens/profile_account_screen.dart';
import '../../../settings/presentation/screens/security_screen.dart';
import '../../../settings/presentation/screens/settings_menu_screen.dart';
import '../../../settings/presentation/widgets/settings_common.dart';
import '../../../settings/presentation/widgets/settings_dialogs.dart';

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
  BuckSettingsContext? settingsContext,
  VoidCallback? onProfileUpdated,
  void Function(String message)? onShowMessage,
}) {
  final effectiveContext =
      settingsContext ??
      BuckSettingsContext(
        displayName: displayName,
        email: email,
        connectionLabel: connectionLabel,
        providerName: connectionLabel.toLowerCase().contains('google')
            ? 'Google'
            : 'Buck Auth',
        isGoogleManaged: connectionLabel.toLowerCase().contains('google'),
      );

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close profile menu',
    barrierColor: Colors.black.withValues(alpha: 0.58),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _ProfileSidePanelOverlay(
        settingsContext: effectiveContext,
        hostNavigator: Navigator.of(context),
        onSignOut: onSignOut,
        onProfileUpdated: onProfileUpdated,
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
  final BuckSettingsContext settingsContext;
  final NavigatorState hostNavigator;
  final Future<void> Function() onSignOut;
  final VoidCallback? onProfileUpdated;
  final void Function(String message)? onShowMessage;

  const _ProfileSidePanelOverlay({
    required this.settingsContext,
    required this.hostNavigator,
    required this.onSignOut,
    this.onProfileUpdated,
    this.onShowMessage,
  });

  @override
  State<_ProfileSidePanelOverlay> createState() =>
      _ProfileSidePanelOverlayState();
}

class _ProfileSidePanelOverlayState extends State<_ProfileSidePanelOverlay>
    with SingleTickerProviderStateMixin {
  bool _accountExpanded = false;
  bool _showMoreExpanded = false;
  bool _settingsExpanded = false;
  bool _dangerExpanded = false;

  double _dragOffsetX = 0.0;
  late final AnimationController _snapBackController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  Animation<double>? _snapBackAnim;

  @override
  void initState() {
    super.initState();
    AppLayout.pushDarkBarSurface();
    SettingsService.instance.ensureLoaded();
    _snapBackController.addListener(() {
      final anim = _snapBackAnim;
      if (anim != null && mounted) {
        setState(() => _dragOffsetX = anim.value);
      }
    });
  }

  @override
  void dispose() {
    _snapBackController.dispose();
    AppLayout.popDarkBarSurface();
    super.dispose();
  }

  void _handleDrawerDragUpdate(DragUpdateDetails details, double panelWidth) {
    if (_snapBackController.isAnimating) {
      _snapBackController.stop();
    }
    setState(() {
      _dragOffsetX = (_dragOffsetX + details.delta.dx).clamp(-panelWidth, 0.0);
    });
  }

  void _handleDrawerDragEnd(DragEndDetails details, double panelWidth) {
    final velocity = details.primaryVelocity ?? 0.0;
    if (velocity < -280 || _dragOffsetX < -panelWidth * 0.30) {
      Navigator.of(context).pop();
      return;
    }
    _snapBackAnim = Tween<double>(begin: _dragOffsetX, end: 0.0).animate(
      CurvedAnimation(parent: _snapBackController, curve: Curves.easeOutCubic),
    );
    _snapBackController.forward(from: 0.0);
  }

  Future<void> _confirmAndSignOut() async {
    final confirmed = await showSignOutConfirmationDialog(context);
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop();
    await widget.onSignOut();
  }

  Future<void> _handleDeletionConfirmed() async {
    widget.hostNavigator.popUntil((route) => route.isFirst);
    widget.onShowMessage?.call(
      'Account deletion scheduled with a 10-day recovery window.',
    );
    await widget.onSignOut();
  }

  void _openScreen(ProfilePanelDestination destination) {
    Navigator.of(context).pop();
    late final Widget screen;
    switch (destination) {
      case ProfilePanelDestination.profileAccount:
        screen = ProfileAccountScreen(
          settingsContext: widget.settingsContext,
          onProfileUpdated: widget.onProfileUpdated,
        );
        break;
      case ProfilePanelDestination.security:
        screen = SecurityScreen(settingsContext: widget.settingsContext);
        break;
      case ProfilePanelDestination.appearance:
        screen = const AppearanceScreen();
        break;
      case ProfilePanelDestination.feedback:
        screen = const FeedbackScreen();
        break;
      case ProfilePanelDestination.settingsMenu:
        screen = SettingsMenuScreen(
          settingsContext: widget.settingsContext,
          onSignOut: widget.onSignOut,
          onProfileUpdated: widget.onProfileUpdated,
        );
        break;
      case ProfilePanelDestination.dangerZone:
        screen = DangerZoneScreen(
          onDeletionConfirmed: _handleDeletionConfirmed,
        );
        break;
    }
    widget.hostNavigator.push(CupertinoPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    final size = MediaQuery.sizeOf(context);
    final topInset = AppLayout.topSafeInset(context);
    final bottomInset = AppLayout.bottomSafeInset(context);
    final leftInset = AppLayout.leftSafeInset(context);
    final panelWidth = math.min(378.0, size.width * 0.88);
    final borderColor = palette.subtleBorder;
    final tileBg = palette.panelTileBg;
    final cardBg = palette.panelCardBg;

    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        offset: Offset(_dragOffsetX, 0),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          excludeFromSemantics: true,
          onHorizontalDragUpdate: (d) => _handleDrawerDragUpdate(d, panelWidth),
          onHorizontalDragEnd: (d) => _handleDrawerDragEnd(d, panelWidth),
          onHorizontalDragCancel: () {
            if (_dragOffsetX != 0.0) {
              _handleDrawerDragEnd(DragEndDetails(), panelWidth);
            }
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              key: const Key('profile_side_panel'),
              width: panelWidth,
              height: double.infinity,
          decoration: BoxDecoration(
            color: palette.panelOverlayBg,
            border: Border(
              right: BorderSide(color: palette.glassCardBorder, width: 1),
            ),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  math.max(14.0, leftInset + 10.0),
                  math.max(48.0, topInset + 16.0),
                  14,
                  math.max(36.0, bottomInset + 20.0),
                ),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileAccountCard(
                  displayName: widget.settingsContext.displayName,
                  email: widget.settingsContext.email,
                  connectionLabel: widget.settingsContext.connectionLabel,
                  expanded: _accountExpanded,
                  onToggleExpand: () {
                    setState(() => _accountExpanded = !_accountExpanded);
                  },
                  onManageAccount: () =>
                      _openScreen(ProfilePanelDestination.profileAccount),
                  onSignOutTap: _confirmAndSignOut,
                ),
                const SizedBox(height: 20),
                _ShortcutsSection(
                  onSecurityTap: () =>
                      _openScreen(ProfilePanelDestination.security),
                  onAppearanceTap: () =>
                      _openScreen(ProfilePanelDestination.appearance),
                  onFeedbackTap: () =>
                      _openScreen(ProfilePanelDestination.feedback),
                ),
                const SizedBox(height: 20),
                _NavigationTileGrid(
                  onProfileTap: () =>
                      _openScreen(ProfilePanelDestination.profileAccount),
                  onSecurityTap: () =>
                      _openScreen(ProfilePanelDestination.security),
                  onAppearanceTap: () =>
                      _openScreen(ProfilePanelDestination.appearance),
                  onFeedbackTap: () =>
                      _openScreen(ProfilePanelDestination.feedback),
                ),
                if (_showMoreExpanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tileBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Preferences Shortcut',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ExpandedActionRow(
                          iconPath: 'assets/icons/profile_panel_settings.svg',
                          label: 'Open Full Settings',
                          onTap: () =>
                              _openScreen(ProfilePanelDestination.settingsMenu),
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
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: borderColor, width: 1),
                      bottom: BorderSide(color: borderColor, width: 1),
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
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: _settingsExpanded
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: cardBg.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: borderColor,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _ExpandedActionRow(
                                        iconPath:
                                            'assets/icons/profile_panel_user_round.svg',
                                        label: 'Profile & Account',
                                        onTap: () => _openScreen(
                                          ProfilePanelDestination.profileAccount,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _ExpandedActionRow(
                                        iconPath:
                                            'assets/icons/profile_panel_shield_check.svg',
                                        label: 'Security & Connected Apps',
                                        onTap: () => _openScreen(
                                          ProfilePanelDestination.security,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _ExpandedActionRow(
                                        iconPath:
                                            'assets/icons/profile_panel_palette.svg',
                                        label: 'Appearance & Theme',
                                        onTap: () => _openScreen(
                                          ProfilePanelDestination.appearance,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _ExpandedActionRow(
                                        iconPath:
                                            'assets/icons/profile_panel_settings.svg',
                                        label: 'All Settings',
                                        onTap: () => _openScreen(
                                          ProfilePanelDestination.settingsMenu,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: borderColor,
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
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: _dangerExpanded
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _ExpandedActionRow(
                                  iconPath:
                                      'assets/icons/profile_panel_triangle_alert.svg',
                                  label:
                                      'Account deletion & sensitive actions',
                                  labelColor: palette.dangerTitle,
                                  onTap: () => _openScreen(
                                    ProfilePanelDestination.dangerZone,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: math.max(24.0, topInset + 14.0),
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          palette.panelOverlayBg,
                          palette.panelOverlayBg.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: math.max(24.0, bottomInset + 14.0),
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          palette.panelOverlayBg,
                          palette.panelOverlayBg.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    final cardBg = palette.panelCardBg;
    final borderColor = palette.subtleBorder;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('panel_profile_card_toggle'),
            onTap: onToggleExpand,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ValueListenableBuilder(
                    valueListenable: SettingsService.instance.customAvatarBytes,
                    builder: (context, bytes, _) {
                      return Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: palette.inputBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 1),
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
                                width: 24,
                                height: 24,
                              )
                            : null,
                      );
                    },
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
                            color: palette.textPrimary,
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
                            color: palette.textSecondary,
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
                    decoration: BoxDecoration(
                      color: palette.inputBg,
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
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: expanded
                ? Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: borderColor,
                        ),
                        const SizedBox(height: 10),
                        _ExpandedActionRow(
                          iconPath: 'assets/icons/profile_panel_user_round.svg',
                          label: 'Manage Profile & Account',
                          onTap: onManageAccount,
                        ),
                        const SizedBox(height: 8),
                        SettingsRedButton(
                          key: const Key('panel_profile_sign_out_button'),
                          label: 'Sign out',
                          onTap: onSignOutTap,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor, width: 1)),
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
                      color: palette.textSecondary,
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
    final palette = BuckPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your shortcuts',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 20 / 14,
            color: palette.textPrimary,
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
    final palette = BuckPalette.of(context);
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
              color: palette.panelCardBg,
              borderRadius: BorderRadius.circular(14),
              border: palette.isLight
                  ? Border.all(color: palette.subtleBorder, width: 1)
                  : null,
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
              color: palette.textSecondary,
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
    final palette = BuckPalette.of(context);
    return Material(
      color: palette.panelTileBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 92,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.subtleBorder, width: 1),
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
                  color: palette.textPrimary,
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
    final palette = BuckPalette.of(context);
    return Material(
      color: palette.inputBg,
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
              color: palette.textPrimary,
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
    final palette = BuckPalette.of(context);
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
                    color: palette.textPrimary,
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
    final palette = BuckPalette.of(context);
    return Material(
      color: palette.navBarBg,
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
                    color: labelColor ?? palette.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: palette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
