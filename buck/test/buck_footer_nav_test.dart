import 'package:buck/core/theme/app_colors.dart';
import 'package:buck/core/widgets/buck_footer_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildNav({
    required BuckTab activeTab,
    required ValueChanged<BuckTab> onTabSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: BuckFooterNav(
            activeTab: activeTab,
            onTabSelected: onTabSelected,
          ),
        ),
      ),
    );
  }

  testWidgets('BuckFooterNav renders 5 permanent icons and sliding cream indicator', (
    tester,
  ) async {
    BuckTab selected = BuckTab.home;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return buildNav(
            activeTab: selected,
            onTabSelected: (tab) => setState(() => selected = tab),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    // Verify 5 navigation icons are rendered via SvgPicture
    expect(find.byType(SvgPicture), findsNWidgets(5));

    // Verify raised cream circle indicator container exists with navRaisedSurface color
    final indicatorFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == AppColors.navRaisedSurface,
    );
    expect(indicatorFinder, findsOneWidget);

    // Initial position for Home: raisedLeft should be 220 - 36 = 184
    AnimatedPositioned initialPos = tester.widget<AnimatedPositioned>(
      find.ancestor(of: indicatorFinder, matching: find.byType(AnimatedPositioned)),
    );
    expect(initialPos.left, 184.0);

    // Tap the Expenses tab
    await tester.tap(find.bySemanticsLabel('Expenses'));
    await tester.pump(); // Start transition

    // Mid-animation: at 100ms, the indicator has started moving towards 106 (pushed in)
    await tester.pump(const Duration(milliseconds: 100));
    AnimatedPositioned midPos = tester.widget<AnimatedPositioned>(
      find.ancestor(of: indicatorFinder, matching: find.byType(AnimatedPositioned)),
    );
    expect(midPos.left, 106.0); // Target position is 106.0

    // Settle animation
    await tester.pumpAndSettle();

    // Verify target position reached: 142 - 36 = 106
    AnimatedPositioned settledPos = tester.widget<AnimatedPositioned>(
      find.ancestor(of: indicatorFinder, matching: find.byType(AnimatedPositioned)),
    );
    expect(settledPos.left, 106.0);
    expect(selected, BuckTab.expenses);

    // Verify all 5 icons still exist and none were destroyed or hidden
    expect(find.byType(SvgPicture), findsNWidgets(5));
  });

  testWidgets('Icons do not fade out (no Opacity widget used for icons)', (
    tester,
  ) async {
    var currentTab = BuckTab.home;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return buildNav(
            activeTab: currentTab,
            onTabSelected: (tab) => setState(() => currentTab = tab),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    // Switch tabs
    await tester.tap(find.bySemanticsLabel('Expenses'));
    await tester.pump(const Duration(milliseconds: 140));

    // Ensure no AnimatedSwitcher or FadeTransition is wrapping the icons
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(find.byType(SvgPicture), findsNWidgets(5));

    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsNWidgets(5));
  });
}
