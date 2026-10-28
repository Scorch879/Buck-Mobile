import 'package:buck/features/expenses/presentation/screens/receipt_scanner_screen.dart';
import 'package:buck/features/finance/data/dev_finance_source.dart';
import 'package:buck/features/finance/presentation/finance_controller.dart';
import 'package:buck/features/shell/presentation/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiptScannerScreen', () {
    testWidgets('renders all Figma 2480:672 elements and toggles flash',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReceiptScannerScreen(enableLiveCamera: false),
        ),
      );
      await tester.pumpAndSettle();

      // Toolbar
      expect(find.text('Scan receipt'), findsOneWidget);
      expect(find.byKey(const Key('scanner_close_button')), findsOneWidget);
      expect(find.byKey(const Key('scanner_flash_button')), findsOneWidget);

      // Framing instructions
      expect(find.text('Line up your receipt.'), findsOneWidget);
      expect(
        find.text('Fit the whole receipt inside the frame.'),
        findsOneWidget,
      );

      // Viewfinder alignment feedback pill
      expect(find.text('Keep it flat. Hold steady.'), findsOneWidget);

      // Capture controls & helper text
      expect(find.byKey(const Key('scanner_gallery_button')), findsOneWidget);
      expect(find.byKey(const Key('scanner_shutter_button')), findsOneWidget);
      expect(find.text('Single receipt'), findsOneWidget);
      expect(
        find.text('Review the details before adding an expense.'),
        findsOneWidget,
      );

      // Toggle flash control
      await tester.tap(find.byKey(const Key('scanner_flash_button')));
      await tester.pump();
      expect(find.bySemanticsLabel('Turn flash off'), findsOneWidget);
    });

    testWidgets(
        'clicking Scan Receipt button in MainShell opens ReceiptScannerScreen and populates Add Spending',
        (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = FinanceController(DevFinanceSource());

      await tester.pumpWidget(
        MaterialApp(
          home: MainShell(financeController: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Scan Receipt" quick action button on Home Dashboard
      await tester.tap(find.text('Scan Receipt'));
      await tester.pumpAndSettle();

      // ReceiptScannerScreen should now be visible
      expect(find.byType(ReceiptScannerScreen), findsOneWidget);
      expect(find.text('Line up your receipt.'), findsOneWidget);

      // Tap shutter button to capture receipt
      await tester.tap(find.byKey(const Key('scanner_shutter_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Receipt captured!'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // After capture, Add Spending overlay opens pre-filled for review
      expect(find.text('Add Spending'), findsOneWidget);
      expect(find.text('842.50'), findsOneWidget);
      expect(find.text('Fresh Mart - Makati (#098765)'), findsOneWidget);
    });
  });
}
