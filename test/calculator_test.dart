import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/core/theme/app_theme.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/features/home/providers/home_providers.dart';
import 'package:monetra/features/home/screens/all_features_screen.dart';
import 'package:monetra/features/tools/screens/money_calculator_screen.dart';
import 'package:monetra/features/tools/utils/money_calculator_engine.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Kalkulator Uang (MoneyCalculatorEngine & UI)', () {
    test('Engine evaluates Rupiah shortcuts, precedence, percentage, negative & div-by-zero cleanly', () {
      // 1. Shortcut 000 + operator precedence (100rb + 2 x 50rb = 200rb)
      var s = const MoneyCalculatorState();
      s = MoneyCalculatorEngine.inputDigit(s, '1');
      s = MoneyCalculatorEngine.inputDigit(s, '0');
      s = MoneyCalculatorEngine.inputDigit(s, '0');
      s = MoneyCalculatorEngine.inputDigit(s, '000'); // 100.000
      s = MoneyCalculatorEngine.inputOperator(s, '+');
      s = MoneyCalculatorEngine.inputDigit(s, '2');
      s = MoneyCalculatorEngine.inputOperator(s, '×');
      s = MoneyCalculatorEngine.inputDigit(s, '5');
      s = MoneyCalculatorEngine.inputDigit(s, '0');
      s = MoneyCalculatorEngine.inputDigit(s, '000'); // 50.000
      s = MoneyCalculatorEngine.equals(s);
      expect(MoneyCalculatorEngine.evaluate(s.tokens).value, 200000);

      // 2. Persentase diskon / tabungan: 5.000.000 - 20% = 4.000.000
      var p = const MoneyCalculatorState();
      p = MoneyCalculatorEngine.inputWalletBalance(p, 5000000);
      p = MoneyCalculatorEngine.inputOperator(p, '-');
      p = MoneyCalculatorEngine.inputDigit(p, '2');
      p = MoneyCalculatorEngine.inputDigit(p, '0');
      p = MoneyCalculatorEngine.inputPercent(p);
      p = MoneyCalculatorEngine.equals(p);
      expect(MoneyCalculatorEngine.evaluate(p.tokens).value, 4000000);

      // 3. Pembagian tidak habis 1.000.000 / 3 * 3 = 1.000.000
      var d = const MoneyCalculatorState();
      d = MoneyCalculatorEngine.inputWalletBalance(d, 1000000);
      d = MoneyCalculatorEngine.inputOperator(d, '÷');
      d = MoneyCalculatorEngine.inputDigit(d, '3');
      d = MoneyCalculatorEngine.inputOperator(d, '×');
      d = MoneyCalculatorEngine.inputDigit(d, '3');
      d = MoneyCalculatorEngine.equals(d);
      expect(MoneyCalculatorEngine.evaluate(d.tokens).value, 1000000);

      // 4. Pembagian dengan 0 menghasilkan pesan error aman
      var z = const MoneyCalculatorState();
      z = MoneyCalculatorEngine.inputWalletBalance(z, 100000);
      z = MoneyCalculatorEngine.inputOperator(z, '÷');
      z = MoneyCalculatorEngine.inputDigit(z, '0');
      z = MoneyCalculatorEngine.equals(z);
      expect(z.errorMessage, 'Tidak bisa dibagi 0');

      // 5. Hasil minus terformat jelas (-Rp 250.000)
      expect(MoneyCalculatorEngine.formatNumber(-250000), '-Rp 250.000');
    });

    testWidgets(
        'MoneyCalculatorScreen loads wallet balances & calculates without overflow at 320px',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bca = AccountWithBalance(
        account: Account(
          id: 1,
          name: 'BCA',
          type: 'bank',
          category: 'harian',
          colorHex: '0xFF0066AE',
          iconCodePoint: Icons.account_balance.codePoint,
          initialBalance: 2000000,
          logoKey: 'bca',
          createdAt: DateTime(2026, 1, 1),
        ),
        balance: 2000000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            balanceSummaryProvider.overrideWith(
              (ref) async => const BalanceSummary(
                dailySpendingBalance: 2000000,
                savingsBalance: 3000000,
                totalNetWorth: 5000000,
              ),
            ),
            accountsWithBalanceProvider.overrideWith((ref) async => [bca]),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MoneyCalculatorScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ketuk preset Siap Pakai (Rp 5.000.000) -> kurangi 750.000 -> tekan '='
      await tester.tap(find.text('Siap Pakai (Rp 5.000.000)'));
      await tester.pump();
      await tester.tap(find.text('−'));
      await tester.pump();
      await tester.tap(find.text('7'));
      await tester.tap(find.text('5'));
      await tester.tap(find.text('0'));
      await tester.tap(find.text('000'));
      await tester.pump();
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();

      expect(find.text('Rp 4.250.000'), findsOneWidget);
      expect(
        find.text('5.000.000 - 750.000 = Rp 4.250.000'),
        findsOneWidget,
      );
    });

    testWidgets('AllFeaturesScreen exposes Kalkulator Uang entry',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AllFeaturesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kalkulator Uang'), findsOneWidget);
    });
  });
}
