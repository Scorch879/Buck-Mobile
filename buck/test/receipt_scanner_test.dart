import 'dart:typed_data';

import 'package:buck/features/expenses/data/receipt_ocr_processor.dart';
import 'package:buck/features/expenses/presentation/add_expense_dialog.dart';
import 'package:buck/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:buck/features/expenses/presentation/screens/receipt_scanner_screen.dart';
import 'package:buck/features/finance/data/dev_finance_source.dart';
import 'package:buck/features/finance/data/finance_models.dart';
import 'package:buck/features/finance/data/finance_repository.dart';
import 'package:buck/features/finance/domain/finance_snapshot.dart';
import 'package:buck/features/finance/presentation/finance_controller.dart';
import 'package:buck/features/income/presentation/add_income_dialog.dart';
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

  group('ReceiptOcrProcessor & EdgeImageOps', () {
    test('parses PH retail receipt with explicit 12% VAT, merchant, date and total', () {
      const sampleReceipt = '''
OFFICIAL RECEIPT
JOLLIBEE - BGC
TIN: 000-111-222-000
DATE: 2026-10-15
Chickenjoy Bucket    752.23
SUBTOTAL             752.23
12% VAT:              90.27
TOTAL AMOUNT DUE     842.50
CASH               1,000.00
CHANGE               157.50
''';

      final parsed = ReceiptOcrProcessor.parseReceiptText(sampleReceipt);
      expect(parsed.merchantName, 'Jollibee - BGC');
      expect(parsed.date, DateTime(2026, 10, 15));
      expect(parsed.totalAmount, 842.50);
      expect(parsed.evatAmount, 90.27);
      expect(parsed.vatableSales, 752.23);
      expect(parsed.evatWasExplicit, isTrue);
      expect(parsed.categoryName, 'Food');
    });

    test('computes BIR 12% EVAT fallback when explicit VAT line is omitted', () {
      const sampleReceipt = '''
SHELL MAGALLANES
Oct 12, 2026
Fuel Unleaded      1,120.00
GRAND TOTAL        1,120.00
''';

      final parsed = ReceiptOcrProcessor.parseReceiptText(sampleReceipt);
      expect(parsed.totalAmount, 1120.00);
      expect(parsed.vatableSales, 1000.00);
      expect(parsed.evatAmount, 120.00);
      expect(parsed.evatWasExplicit, isFalse);
      expect(parsed.categoryName, 'Transportation');
    });

    test('sanitizes PH mobile numbers and email PII', () {
      const raw = 'Call +639171234567 or 09171234567 | cashier@store.ph';
      final sanitized = ReceiptOcrProcessor.sanitizePii(raw);
      expect(sanitized, isNot(contains('9171234567')));
      expect(sanitized, isNot(contains('cashier@store.ph')));
      expect(sanitized, contains('[REDACTED_PHONE]'));
      expect(sanitized, contains('[REDACTED_EMAIL]'));
    });

    test('EdgeImageOps flags dark or low-detail captures with retake warning', () {
      final darkBytes = Uint8List.fromList(List.filled(300, 12));
      final assessment = EdgeImageOps.evaluateAndPreprocess(darkBytes);
      expect(assessment.isLowQuality, isTrue);
      expect(
        assessment.qualityWarning,
        'Image text unclear - please retake with flash or proceed manually',
      );
    });
  });

  group('Multi-screen OCR UI integration', () {
    const testWallet = Wallet(id: 'w1', name: 'Cash', balance: 5000);

    testWidgets('AddExpenseDialog renders OCR verification banner with 12% EVAT',
        (tester) async {
      final receipt = ScannedReceiptResult(
        amount: 842.50,
        categoryName: 'Shopping',
        description: 'Fresh Mart - Makati (#098765)',
        date: DateTime(2026, 10, 15),
        evatAmount: 90.27,
        vatableSales: 752.23,
        processingTimeMs: 42,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddExpenseDialog(
              wallet: testWallet,
              initialReceipt: receipt,
              onSubmit: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ocr_verification_banner')), findsOneWidget);
      expect(
        find.text('Vatable Sales: ₱752.23 • 12% EVAT: ₱90.27'),
        findsOneWidget,
      );
      expect(find.text('842.50'), findsOneWidget);
      expect(find.text('Fresh Mart - Makati (#098765)'), findsOneWidget);
    });

    testWidgets('ExpensesScreen displays Scan button and triggers callback',
        (tester) async {
      var scannedTriggered = false;
      final snapshot = FinanceSnapshot.fromData(
        FinanceData(
          profileName: 'Test',
          activeWalletId: 'w1',
          wallets: const [testWallet],
          expenses: [
            ExpenseRecord(
              id: 'e1',
              walletId: 'w1',
              categoryName: 'Food',
              amount: 120,
              description: 'Coffee',
              spentOn: DateTime(2026, 10, 15),
            ),
          ],
          incomes: const [],
          advisories: const [],
        ),
        now: DateTime(2026, 10, 15),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpensesScreen(
              snapshot: snapshot,
              onRefresh: () async {},
              onScanReceipt: () => scannedTriggered = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scanFinder = find.byKey(const Key('expenses_scan_receipt_button'));
      expect(scanFinder, findsOneWidget);
      await tester.ensureVisible(scanFinder);
      await tester.tap(scanFinder);
      await tester.pump();
      expect(scannedTriggered, isTrue);
    });

    testWidgets('AddIncomeDialog populates fields and infers source from OCR result',
        (tester) async {
      final incomeSlip = ScannedReceiptResult(
        amount: 25000.00,
        categoryName: 'Other',
        description: 'Acme Corp Monthly Payroll Salary',
        date: DateTime(2026, 10, 15),
        rawText: 'ACME CORP PAYSLIP SALARY CREDIT 25,000.00',
        processingTimeMs: 35,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddIncomeDialog(
              wallet: testWallet,
              initialReceipt: incomeSlip,
              onSubmit: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('income_ocr_verification_banner')),
        findsOneWidget,
      );
      expect(find.text('25000.00'), findsOneWidget);
      expect(find.text('Acme Corp Monthly Payroll Salary'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
    });
  });
}
