import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/widgets/buck_footer_nav.dart';
import 'buck_onboarding_targets.dart';

class _TextSpanSpec {
  final String text;
  final bool bold;
  const _TextSpanSpec(this.text, {this.bold = false});
}

class _TargetAnchor {
  final GlobalKey Function(BuckOnboardingTargets targets) resolveKey;
  final BorderRadius radius;
  final EdgeInsets padding;

  const _TargetAnchor({
    required this.resolveKey,
    required this.radius,
    this.padding = EdgeInsets.zero,
  });
}

class _OnboardingStepSpec {
  final BuckTab tab;
  final GlobalKey Function(BuckOnboardingTargets targets) scrollKey;
  final double scrollAlignment;
  final List<_TargetAnchor> cardCutouts;
  final List<_TargetAnchor> lineHighlights;
  final bool preferBottomDock;
  final String duckAsset;
  final bool duckOnRight;
  final bool flipDuckX;
  final double duckTiltRadians;
  final List<_TextSpanSpec> copySpans;

  const _OnboardingStepSpec({
    required this.tab,
    required this.scrollKey,
    this.scrollAlignment = 0.18,
    required this.cardCutouts,
    required this.lineHighlights,
    this.preferBottomDock = false,
    required this.duckAsset,
    required this.duckOnRight,
    this.flipDuckX = false,
    this.duckTiltRadians = 0,
    required this.copySpans,
  });
}

const double _step5TiltRadians = -25.69 * math.pi / 180;

const List<String> _duckAssets = [
  'assets/images/buck_duck_waving.png',
  'assets/images/buck_duck_presenting.png',
  'assets/images/buck_duck_confident.png',
];

final List<_OnboardingStepSpec> _onboardingSteps = [
  _OnboardingStepSpec(
    tab: BuckTab.home,
    scrollKey: (t) => t.quickActionsCardKey,
    scrollAlignment: 0.1,
    cardCutouts: [
      _TargetAnchor(
        resolveKey: (t) => t.quickActionsCardKey,
        radius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(2),
      ),
    ],
    lineHighlights: [
      _TargetAnchor(
        resolveKey: (t) => t.quickActionsCardKey,
        radius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(2),
      ),
    ],
    duckAsset: 'assets/images/buck_duck_waving.png',
    duckOnRight: true,
    copySpans: const [
      _TextSpanSpec('Tap a '),
      _TextSpanSpec('Quick Action', bold: true),
      _TextSpanSpec(
        ' above to scan receipts, track money, or make a transfer!',
      ),
    ],
  ),
  _OnboardingStepSpec(
    tab: BuckTab.home,
    scrollKey: (t) => t.quickActionsCardKey,
    scrollAlignment: 0.1,
    cardCutouts: [
      _TargetAnchor(
        resolveKey: (t) => t.quickActionsCardKey,
        radius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(2),
      ),
    ],
    lineHighlights: [
      _TargetAnchor(
        resolveKey: (t) => t.addExpenseActionKey,
        radius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(5),
      ),
    ],
    duckAsset: 'assets/images/buck_duck_presenting.png',
    duckOnRight: true,
    copySpans: const [
      _TextSpanSpec('Tap '),
      _TextSpanSpec('Add Expense', bold: true),
      _TextSpanSpec(
        ' to log a purchase and keep track of where your money goes!',
      ),
    ],
  ),
  _OnboardingStepSpec(
    tab: BuckTab.home,
    scrollKey: (t) => t.quickActionsCardKey,
    scrollAlignment: 0.1,
    cardCutouts: [
      _TargetAnchor(
        resolveKey: (t) => t.quickActionsCardKey,
        radius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(2),
      ),
    ],
    lineHighlights: [
      _TargetAnchor(
        resolveKey: (t) => t.addIncomeActionKey,
        radius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(5),
      ),
    ],
    duckAsset: 'assets/images/buck_duck_confident.png',
    duckOnRight: false,
    flipDuckX: true,
    copySpans: const [
      _TextSpanSpec('Tap '),
      _TextSpanSpec('Add Income', bold: true),
      _TextSpanSpec(
        ' to record your earnings and keep your balance up to date!',
      ),
    ],
  ),
  _OnboardingStepSpec(
    tab: BuckTab.wallet,
    scrollKey: (t) => t.manageWalletsCardKey,
    scrollAlignment: 0.16,
    cardCutouts: [
      _TargetAnchor(
        resolveKey: (t) => t.manageWalletsCardKey,
        radius: BorderRadius.circular(26),
        padding: const EdgeInsets.all(2),
      ),
    ],
    lineHighlights: [
      _TargetAnchor(
        resolveKey: (t) => t.newWalletButtonKey,
        radius: BorderRadius.circular(10),
        padding: const EdgeInsets.all(4),
      ),
    ],
    duckAsset: 'assets/images/buck_duck_confident.png',
    duckOnRight: true,
    copySpans: const [
      _TextSpanSpec('Tap '),
      _TextSpanSpec('+ New Wallet', bold: true),
      _TextSpanSpec(
        ' to add your first wallet and start managing your money!',
      ),
    ],
  ),
  _OnboardingStepSpec(
    tab: BuckTab.expenses,
    scrollKey: (t) => t.recentExpensesCardKey,
    scrollAlignment: 0.15,
    cardCutouts: [
      _TargetAnchor(
        resolveKey: (t) => t.recentExpensesCardKey,
        radius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(2),
      ),
    ],
    lineHighlights: [
      _TargetAnchor(
        resolveKey: (t) => t.expensesAddButtonKey,
        radius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(6),
      ),
    ],
    duckAsset: 'assets/images/buck_duck_presenting.png',
    duckOnRight: true,
    duckTiltRadians: _step5TiltRadians,
    copySpans: const [
      _TextSpanSpec('Tap '),
      _TextSpanSpec('+', bold: true),
      _TextSpanSpec(' to log an expense, or '),
      _TextSpanSpec('View more', bold: true),
      _TextSpanSpec(' to see all your spending in one place!'),
    ],
  ),
  _OnboardingStepSpec(
    tab: BuckTab.goals,
    scrollKey: (t) => t.goalsHeroSectionKey,
    scrollAlignment: 0.12,
    cardCutouts: [
      _TargetAnchor(
        resolveKey: (t) => t.goalsHeroSectionKey,
        radius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(8),
      ),
    ],
    lineHighlights: [
      _TargetAnchor(
        resolveKey: (t) => t.createGoalButtonKey,
        radius: BorderRadius.circular(10),
        padding: const EdgeInsets.all(4),
      ),
      _TargetAnchor(
        resolveKey: (t) => t.allocateFundsButtonKey,
        radius: BorderRadius.circular(14),
        padding: const EdgeInsets.all(4),
      ),
    ],
    duckAsset: 'assets/images/buck_duck_confident.png',
    duckOnRight: true,
    copySpans: const [
      _TextSpanSpec('Tap '),
      _TextSpanSpec('+ Create Goal', bold: true),
      _TextSpanSpec(' to start saving, then '),
      _TextSpanSpec('Allocate Funds from Wallet', bold: true),
      _TextSpanSpec(' to grow it!'),
    ],
  ),
  _OnboardingStepSpec(
    tab: BuckTab.stats,
    scrollKey: (t) => t.categoryBreakdownCardKey,
    scrollAlignment: 0.08,
    cardCutouts: [
      _TargetAnchor(
        resolveKey: (t) => t.categoryBreakdownCardKey,
        radius: BorderRadius.circular(28),
        padding: const EdgeInsets.all(2),
      ),
      _TargetAnchor(
        resolveKey: (t) => t.spendingTrendCardKey,
        radius: BorderRadius.circular(28),
        padding: const EdgeInsets.all(2),
      ),
    ],
    lineHighlights: [
      _TargetAnchor(
        resolveKey: (t) => t.categoryPeriodPillsKey,
        radius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      _TargetAnchor(
        resolveKey: (t) => t.trendPeriodPillsKey,
        radius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
    ],
    preferBottomDock: true,
    duckAsset: 'assets/images/buck_duck_waving.png',
    duckOnRight: false,
    copySpans: const [
      _TextSpanSpec('Switch '),
      _TextSpanSpec('time filters', bold: true),
      _TextSpanSpec(' to explore your spending by category and spot trends!'),
    ],
  ),
];

/// Interactive 7-step Figma onboarding tutorial overlay shown only to newly
/// signed up users inside [MainShell].
class BuckOnboardingOverlay extends StatefulWidget {
  final BuckOnboardingTargets targets;
  final BuckTab currentTab;
  final ValueChanged<BuckTab> onNavigateToTab;
  final VoidCallback onComplete;

  const BuckOnboardingOverlay({
    super.key,
    required this.targets,
    required this.currentTab,
    required this.onNavigateToTab,
    required this.onComplete,
  });

  static const int totalSteps = 7;

  @override
  State<BuckOnboardingOverlay> createState() => _BuckOnboardingOverlayState();
}

class _BuckOnboardingOverlayState extends State<BuckOnboardingOverlay>
    with TickerProviderStateMixin {
  int _stepIndex = 0;
  List<RRect> _cardCutouts = const [];
  List<RRect> _lineHighlights = const [];
  Timer? _settleTimer;
  int _measureGeneration = 0;
  bool _precachedDucks = false;

  late final AnimationController _bobController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activateStep(0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precachedDucks) {
      _precachedDucks = true;
      for (final asset in _duckAssets) {
        unawaited(precacheImage(AssetImage(asset), context));
      }
    }
  }

  @override
  void didUpdateWidget(covariant BuckOnboardingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTab != widget.currentTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _measureTargets();
      });
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _bobController.dispose();
    super.dispose();
  }

  _OnboardingStepSpec get _currentStep => _onboardingSteps[_stepIndex];

  void _activateStep(int index) {
    _settleTimer?.cancel();
    final generation = ++_measureGeneration;
    final spec = _onboardingSteps[index];

    if (mounted) {
      setState(() {
        _stepIndex = index;
      });
    }

    if (widget.currentTab != spec.tab) {
      widget.onNavigateToTab(spec.tab);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || generation != _measureGeneration) return;
      await _scrollStepIntoView(spec, generation);
      if (!mounted || generation != _measureGeneration) return;
      _measureTargets();

      // Re-measure after PageView transition & scroll physics settle (~360ms).
      _settleTimer = Timer(const Duration(milliseconds: 360), () async {
        if (!mounted || generation != _measureGeneration) return;
        await _scrollStepIntoView(spec, generation);
        if (!mounted || generation != _measureGeneration) return;
        _measureTargets();
      });
    });
  }

  Future<void> _scrollStepIntoView(
    _OnboardingStepSpec spec,
    int generation,
  ) async {
    final targetContext = spec.scrollKey(widget.targets).currentContext;
    if (targetContext == null || !targetContext.mounted) return;
    try {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: spec.scrollAlignment,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      // Target not inside a Scrollable; safe to ignore.
    }
    if (!mounted || generation != _measureGeneration) return;
  }

  RRect? _measureAnchor(
    _TargetAnchor anchor,
    RenderBox overlayBox,
  ) {
    final targetContext = anchor.resolveKey(widget.targets).currentContext;
    if (targetContext == null || !targetContext.mounted) return null;
    final renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final topLeft = overlayBox.globalToLocal(
      renderObject.localToGlobal(Offset.zero),
    );
    final rawRect = topLeft & renderObject.size;
    final padded = anchor.padding.inflateRect(rawRect);
    final size = overlayBox.size;
    final clamped = Rect.fromLTRB(
      padded.left.clamp(6.0, math.max(6.0, size.width - 6.0)),
      padded.top.clamp(6.0, math.max(6.0, size.height - 6.0)),
      padded.right.clamp(6.0, math.max(6.0, size.width - 6.0)),
      padded.bottom.clamp(6.0, math.max(6.0, size.height - 6.0)),
    );
    if (clamped.width <= 4 || clamped.height <= 4) return null;

    return RRect.fromRectAndCorners(
      clamped,
      topLeft: anchor.radius.topLeft,
      topRight: anchor.radius.topRight,
      bottomLeft: anchor.radius.bottomLeft,
      bottomRight: anchor.radius.bottomRight,
    );
  }

  /// Ensures multi-card cutouts never overlap vertically (so `PathFillType.evenOdd`
  /// always treats every card interior cleanly as an un-dimmed hole).
  List<RRect> _normalizeCutouts(List<RRect> raw) {
    if (raw.length <= 1) return raw;
    final sorted = List<RRect>.from(raw)
      ..sort((a, b) => a.top.compareTo(b.top));
    final normalized = <RRect>[sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      final prev = normalized.last;
      final curr = sorted[i];
      if (curr.top <= prev.bottom + 2) {
        final adjustedTop = prev.bottom + 2;
        if (curr.bottom - adjustedTop > 12) {
          normalized.add(
            RRect.fromLTRBAndCorners(
              curr.left,
              adjustedTop,
              curr.right,
              curr.bottom,
              topLeft: curr.tlRadius,
              topRight: curr.trRadius,
              bottomLeft: curr.blRadius,
              bottomRight: curr.brRadius,
            ),
          );
        }
      } else {
        normalized.add(curr);
      }
    }
    return normalized;
  }

  void _measureTargets() {
    if (!mounted) return;
    final overlayObject = context.findRenderObject();
    if (overlayObject is! RenderBox || !overlayObject.hasSize) return;

    final spec = _currentStep;
    final cutouts = <RRect>[];
    for (final anchor in spec.cardCutouts) {
      final measured = _measureAnchor(anchor, overlayObject);
      if (measured != null) cutouts.add(measured);
    }

    final highlights = <RRect>[];
    for (final anchor in spec.lineHighlights) {
      final measured = _measureAnchor(anchor, overlayObject);
      if (measured != null) highlights.add(measured);
    }

    setState(() {
      _cardCutouts = _normalizeCutouts(cutouts);
      _lineHighlights = highlights;
    });
  }

  void _goNext() {
    if (_stepIndex >= _onboardingSteps.length - 1) {
      widget.onComplete();
    } else {
      _activateStep(_stepIndex + 1);
    }
  }

  void _goPrevious() {
    if (_stepIndex > 0) {
      _activateStep(_stepIndex - 1);
    }
  }

  double _computeCoachmarkTop({
    required double topSafeBoundary,
    required double bottomSafeBoundary,
    required double coachmarkHeight,
  }) {
    final maxTop = math.max(
      topSafeBoundary,
      bottomSafeBoundary - coachmarkHeight,
    );

    if (_currentStep.preferBottomDock) {
      return maxTop;
    }

    final regions = _cardCutouts.isNotEmpty ? _cardCutouts : _lineHighlights;
    if (regions.isEmpty) {
      return (topSafeBoundary + (bottomSafeBoundary - topSafeBoundary) * 0.45)
          .clamp(topSafeBoundary, maxTop);
    }

    final sorted = List<RRect>.from(regions)
      ..sort((a, b) => a.top.compareTo(b.top));

    bool overlapsAny(double top) {
      final bottom = top + coachmarkHeight;
      for (final rect in sorted) {
        if (bottom > rect.top - 10 && top < rect.bottom + 10) {
          return true;
        }
      }
      return false;
    }

    // Candidate 1: Directly below the highlighted card(s) (matches Figma steps 1-6).
    final belowCards = (sorted.last.bottom + 14).clamp(topSafeBoundary, maxTop);
    if (!overlapsAny(belowCards)) {
      return belowCards;
    }

    // Candidate 2: Above the highlighted card(s) if card extends too low.
    final aboveCards = (sorted.first.top - coachmarkHeight - 14).clamp(
      topSafeBoundary,
      maxTop,
    );
    if (!overlapsAny(aboveCards)) {
      return aboveCards;
    }

    // Fallback: Dock right below the primary highlighted line/button or bottom-most safe edge.
    if (_lineHighlights.isNotEmpty) {
      final lineBottom = (_lineHighlights.first.bottom + 16).clamp(
        topSafeBoundary,
        maxTop,
      );
      return lineBottom;
    }
    return maxTop;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 380;
    final bottomInset = AppLayout.bottomSafeInset(context);
    final topInset = AppLayout.topSafeInset(context);

    const controlsHeight = 64.0;
    final controlsBottom = math.max(12.0, bottomInset + 10);
    final topSafeBoundary = topInset + 64.0;
    final bottomSafeBoundary = size.height - controlsBottom - controlsHeight - 12;
    final duckSize = isCompact ? 104.0 : 124.0;
    final estimatedCoachmarkHeight = isCompact ? 156.0 : 168.0;

    final coachmarkTop = _computeCoachmarkTop(
      topSafeBoundary: topSafeBoundary,
      bottomSafeBoundary: bottomSafeBoundary,
      coachmarkHeight: estimatedCoachmarkHeight,
    );

    final spec = _currentStep;
    final margin = AppLayout.pageMargin(context);

    return Semantics(
      container: true,
      label: 'Buck Onboarding Tutorial, step ${_stepIndex + 1} of 7',
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Even-odd 65% scrim punching out whole cards + crisp #FF994A highlight lines
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('scrim_step_$_stepIndex'),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => CustomPaint(
                    painter: SpotlightScrimPainter(
                      cardCutouts: _cardCutouts,
                      lineHighlights: _lineHighlights,
                      ringProgress: t,
                    ),
                  ),
                ),
              ),

              // 2. Smoothly positioned Duck Mascot + Cream Speech Bubble
              AnimatedPositioned(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                top: coachmarkTop,
                left: margin,
                right: margin,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppLayout.contentMaxWidth,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: slide, child: child),
                        );
                      },
                      child: _DuckBubbleRow(
                        key: ValueKey(_stepIndex),
                        spec: spec,
                        duckSize: duckSize,
                        bobAnimation: _bobController,
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Bottom Tutorial Controls Bar: Skip | Step Dots & Counter | Back/Next
              Positioned(
                left: margin,
                right: margin,
                bottom: controlsBottom,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppLayout.contentMaxWidth,
                    ),
                    child: _OnboardingControlsBar(
                      stepIndex: _stepIndex,
                      totalSteps: _onboardingSteps.length,
                      onSkip: widget.onComplete,
                      onPrevious: _stepIndex > 0 ? _goPrevious : null,
                      onNext: _goNext,
                      onSelectStep: _activateStep,
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

@visibleForTesting
class SpotlightScrimPainter extends CustomPainter {
  final List<RRect> cardCutouts;
  final List<RRect> lineHighlights;
  final double ringProgress;

  const SpotlightScrimPainter({
    required this.cardCutouts,
    required this.lineHighlights,
    required this.ringProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Hardware-accelerated even-odd path punches clean un-dimmed holes for whole cards
    // on both CanvasKit Web (Safari/Chrome) and Impeller/Skia mobile renderers.
    final scrimPath = Path()
      ..fillType = ui.PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    for (final cutout in cardCutouts) {
      scrimPath.addRRect(cutout);
    }

    final scrimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    canvas.drawPath(scrimPath, scrimPaint);

    // Subtle warm edge around each un-dimmed card so card bounds stay crisp.
    if (cardCutouts.isNotEmpty) {
      final cardFramePaint = Paint()
        ..color = AppColors.primaryOrange.withValues(alpha: 0.28 * ringProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25;
      for (final cutout in cardCutouts) {
        canvas.drawRRect(cutout, cardFramePaint);
      }
    }

    if (lineHighlights.isEmpty) return;

    final glowPaint = Paint()
      ..color = AppColors.primaryOrange.withValues(alpha: 0.35 * ringProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final borderPaint = Paint()
      ..color = AppColors.primaryOrange.withValues(alpha: ringProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (final rrect in lineHighlights) {
      canvas.drawRRect(rrect, glowPaint);
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  static bool _rrectListsEqual(List<RRect> a, List<RRect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool shouldRepaint(covariant SpotlightScrimPainter oldDelegate) {
    return oldDelegate.ringProgress != ringProgress ||
        !_rrectListsEqual(oldDelegate.cardCutouts, cardCutouts) ||
        !_rrectListsEqual(oldDelegate.lineHighlights, lineHighlights);
  }
}

class _DuckBubbleRow extends StatelessWidget {
  final _OnboardingStepSpec spec;
  final double duckSize;
  final Animation<double> bobAnimation;

  const _DuckBubbleRow({
    super.key,
    required this.spec,
    required this.duckSize,
    required this.bobAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Expanded(
      child: _SpeechBubble(
        spans: spec.copySpans,
        pointerOnRight: spec.duckOnRight,
      ),
    );

    final duck = AnimatedBuilder(
      animation: bobAnimation,
      builder: (context, child) {
        final dy = math.sin(bobAnimation.value * math.pi) * 3.5;
        return Transform.translate(offset: Offset(0, -dy), child: child);
      },
      child: Transform.rotate(
        angle: spec.duckTiltRadians,
        child: Transform.flip(
          flipX: spec.flipDuckX,
          child: SizedBox(
            width: duckSize,
            height: duckSize,
            child: Image.asset(
              spec.duckAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: spec.duckOnRight
          ? [bubble, const SizedBox(width: 4), duck]
          : [duck, const SizedBox(width: 4), bubble],
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final List<_TextSpanSpec> spans;
  final bool pointerOnRight;

  const _SpeechBubble({
    required this.spans,
    required this.pointerOnRight,
  });

  static const _creamFill = Color(0xFFFFF7EE);
  static const _inkBorder = Color(0xFF424242);
  static const _bodyColor = Color(0xFF48403C);
  static const _boldColor = Color(0xFF2B231F);

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Stack(
      clipBehavior: Clip.none,
      alignment: pointerOnRight ? Alignment.centerRight : Alignment.centerLeft,
      children: [
        // Rotated diamond tail anchored cleanly on the duck-facing edge.
        Positioned(
          right: pointerOnRight ? -6 : null,
          left: pointerOnRight ? null : -6,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _creamFill,
                border: Border.all(color: _inkBorder, width: 1.5),
              ),
            ),
          ),
        ),
        // Speech bubble body
        Container(
          margin: EdgeInsets.only(
            right: pointerOnRight ? 2 : 0,
            left: pointerOnRight ? 0 : 2,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 14 : 16,
            vertical: isCompact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: _creamFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _inkBorder, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.manrope(
                fontSize: isCompact ? 14 : 15,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: _bodyColor,
              ),
              children: [
                for (final span in spans)
                  TextSpan(
                    text: span.text,
                    style: span.bold
                        ? const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _boldColor,
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ),
        // Cream patch across the bubble's inner border edge so tail & body merge seamlessly.
        Positioned(
          right: pointerOnRight ? 2 : null,
          left: pointerOnRight ? null : 2,
          child: Container(
            width: 5,
            height: 18,
            color: _creamFill,
          ),
        ),
      ],
    );
  }
}

class _OnboardingControlsBar extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onSkip;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onSelectStep;

  const _OnboardingControlsBar({
    required this.stepIndex,
    required this.totalSteps,
    required this.onSkip,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectStep,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = stepIndex == totalSteps - 1;
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xEC180F0A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryOrange.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Skip button
          TextButton(
            key: const Key('onboarding_skip_button'),
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD5C5B9),
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 8 : 10,
                vertical: 6,
              ),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Skip',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Step indicator: 1 / 7 + animated dots
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${stepIndex + 1} / $totalSteps',
                  key: const Key('onboarding_step_indicator'),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: const Color(0xFFFFD8BA),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < totalSteps; i++)
                      GestureDetector(
                        key: Key('onboarding_dot_$i'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelectStep(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2.5,
                            vertical: 4,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: i == stepIndex ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: i == stepIndex
                                  ? AppColors.primaryOrange
                                  : i < stepIndex
                                      ? AppColors.primaryOrange
                                          .withValues(alpha: 0.45)
                                      : Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Back chevron (optional when past step 1)
          if (onPrevious != null) ...[
            IconButton(
              key: const Key('onboarding_prev_button'),
              onPressed: onPrevious,
              tooltip: 'Previous step',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 34),
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFFE5D4C7),
                size: 22,
              ),
            ),
            const SizedBox(width: 4),
          ],

          // Next / Done gradient CTA
          GestureDetector(
            key: const Key('onboarding_next_button'),
            onTap: onNext,
            child: Container(
              height: 36,
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [
                    AppColors.gradientOrangeStart,
                    Color(0xFFF48648),
                    AppColors.gradientOrangeEnd,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44FF6A13),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLast ? 'Done' : 'Next',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D110C),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isLast
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    size: 16,
                    color: const Color(0xFF1D110C),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
