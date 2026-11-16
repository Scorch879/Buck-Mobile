import 'dart:typed_data';

import 'package:buck/features/expenses/data/receipt_ocr_processor.dart';
import 'package:buck/features/expenses/presentation/add_expense_dialog.dart';
import 'package:buck/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:buck/features/expenses/presentation/screens/receipt_scanner_screen.dart';
import 'package:buck/features/finance/data/finance_models.dart';
import 'package:buck/features/finance/data/finance_repository.dart';
import 'package:buck/features/finance/domain/finance_snapshot.dart';
import 'package:buck/features/finance/presentation/finance_controller.dart';
import 'package:buck/features/income/presentation/add_income_dialog.dart';
import 'package:buck/features/shell/presentation/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dev_finance_source.dart';

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

      // Capture controls & removed manual entry pill
      expect(find.byKey(const Key('scanner_gallery_button')), findsOneWidget);
      expect(find.byKey(const Key('scanner_shutter_button')), findsOneWidget);
      expect(find.text('Single receipt'), findsOneWidget);
      expect(find.byKey(const Key('scanner_manual_entry_button')), findsNothing);
      expect(find.text('Cancel / Manual entry'), findsNothing);

      // Toggle flash control
      await tester.tap(find.byKey(const Key('scanner_flash_button')));
      await tester.pump();
      expect(find.bySemanticsLabel('Turn flash off'), findsOneWidget);

      // Viewfinder is a portrait receipt rectangle (height > width)
      final viewfinderBox = tester.getSize(find.byType(AspectRatio).first);
      expect(viewfinderBox.height, greaterThan(viewfinderBox.width));
    });

    testWidgets(
        'clicking Scan Receipt button in MainShell opens ReceiptScannerScreen and populates Add Spending',
        (tester) async {
      ReceiptScannerScreen.allowSampleFallbackForTesting = true;
      addTearDown(
        () => ReceiptScannerScreen.allowSampleFallbackForTesting = false,
      );
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

    testWidgets(
        'shutter in production mode does not fabricate a receipt when camera is unavailable',
        (tester) async {
      ReceiptScannerScreen.allowSampleFallbackForTesting = false;
      await tester.pumpWidget(
        const MaterialApp(
          home: ReceiptScannerScreen(enableLiveCamera: true),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('scanner_shutter_button')));
      await tester.pumpAndSettle();

      // Still on scanner with helpful status message instead of fabricated data.
      expect(find.byType(ReceiptScannerScreen), findsOneWidget);
      expect(
        find.text('Camera unavailable — check permission or pick a photo.'),
        findsOneWidget,
      );
      expect(find.text('Fresh Mart - Makati (#098765)'), findsNothing);
    });

    test('processReceipt does not synthesize fake merchant when no bytes exist by default',
        () async {
      final out = await ReceiptOcrProcessor.processReceipt();
      expect(out.usedNativeOcr, isFalse);
      expect(out.parsed.totalAmount, 0);
      expect(out.parsed.merchantName, 'Unreadable receipt');
      expect(out.quality?.isLowQuality, isTrue);
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

    test('parses SM Supermarket BIR receipt ignoring permit Date Issued & Cash', () {
      const realSmReceipt = '''
*** OFFICIAL RECEIPT ***
SM SUPERMARKET - AURA
OPERATED BY SUPERVALUE INC.
VAT REG TIN: 000-158-246-000
MIN: 190451284192837
DATE: 11/14/2026  TIME: 17:42
2x NESTLE FRESH MILK      198.00V
1x GARDENIA CLASSIC        82.50V
TOTAL ITEMS: 3
VATABLE SALES             250.45
12% VAT                    30.05
AMOUNT DUE                280.50
CASH                      500.00
CHANGE                    219.50
BIR PTU No.: FP042021-116-000
Date Issued: 01/15/2021
Valid Until: 01/15/2026
''';

      final parsed = ReceiptOcrProcessor.parseReceiptText(realSmReceipt);
      expect(parsed.merchantName, 'SM Supermarket - Aura');
      expect(parsed.date, DateTime(2026, 11, 14));
      expect(parsed.totalAmount, 280.50);
      expect(parsed.vatableSales, 250.45);
      expect(parsed.evatAmount, 30.05);
      expect(parsed.evatWasExplicit, isTrue);
      expect(parsed.categoryName, 'Food');
    });

    test('parses noisy thermal OCR typos (7-Eleven T0TAL, OO cents, GCash)', () {
      const realSevenEleven = '''
================================
7-ELEVEN PHILIPPINES
STORE #2145 MAKATI AVE
11-12-2026 09:15 AM
GULP 22OZ                  49.OO
SIOPAO ASADO               55.00
BOTTLED WATER              45.00
SUBT0TAL                  133.04
12% VAT                    15.96
T0TAL                 Php 149.OO
GCASH                     149.00
CHANGE                      0.00
''';

      final parsed = ReceiptOcrProcessor.parseReceiptText(realSevenEleven);
      expect(parsed.merchantName, '7-Eleven Philippines');
      expect(parsed.date, DateTime(2026, 11, 12));
      expect(parsed.totalAmount, 149.00);
      expect(parsed.vatableSales, 133.04);
      expect(parsed.evatAmount, 15.96);
      expect(parsed.categoryName, 'Food');
    });

    test('parses Mercury Drug split-line column receipt and flags unreadable photos', () async {
      const realMercury = '''
OPERATED BY MERCURY DRUG CORP.
MERCURY DRUG - GREENBELT
TRANSDATE: Nov 10, 2026
BIOFLU TAB 10S             85.00
ASCORBIC ACID             245.50
VATABLE SALES
295.09
VAT AMOUNT
35.41
TOTAL AMOUNT DUE
330.50
''';

      final parsed = ReceiptOcrProcessor.parseReceiptText(realMercury);
      expect(parsed.merchantName, 'Mercury Drug - Greenbelt');
      expect(parsed.date, DateTime(2026, 11, 10));
      expect(parsed.totalAmount, 330.50);
      expect(parsed.evatAmount, 35.41);
      expect(parsed.vatableSales, 295.09);
      expect(parsed.categoryName, 'Health & Wellness');

      // Real unreadable bytes must NOT fabricate Fresh Mart 842.50 dummy data
      final unreadable = await ReceiptOcrProcessor.processReceipt(
        imageBytes: Uint8List.fromList(List.filled(128, 20)),
        sourceName: 'IMG_20261115_120000.jpg',
      );
      expect(unreadable.usedNativeOcr, isFalse);
      expect(unreadable.parsed.totalAmount, 0);
      expect(unreadable.parsed.merchantName, 'Unreadable receipt');
      expect(unreadable.quality?.isLowQuality, isTrue);
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
