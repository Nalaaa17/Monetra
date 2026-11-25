import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/core/theme/app_theme.dart';
import 'package:monetra/core/utils/app_snack_bar.dart';
import 'package:monetra/features/home/widgets/floating_bottom_bar.dart';
import 'package:monetra/shared/widgets/app_dialog.dart';

void main() {
  testWidgets('AppDialog renders title, message, and action buttons properly',
      (tester) async {
    bool? confirmed;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                confirmed = await AppDialog.confirm(
                  context,
                  type: AppDialogType.warning,
                  title: 'Hapus Catatan?',
                  message: 'Data ini tidak dapat dikembalikan lagi.',
                  confirmLabel: 'Hapus Sekarang',
                  cancelLabel: 'Batal',
                );
              },
              child: const Text('Buka Dialog'),
            ),
          ),
        ),
      ),
    );

    // Buka dialog
    await tester.tap(find.text('Buka Dialog'));
    await tester.pumpAndSettle();

    // Verifikasi elemen teks dialog
    expect(find.text('Hapus Catatan?'), findsOneWidget);
    expect(find.text('Data ini tidak dapat dikembalikan lagi.'), findsOneWidget);
    expect(find.text('Hapus Sekarang'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);

    // Tap tombol konfirmasi
    await tester.tap(find.text('Hapus Sekarang'));
    await tester.pumpAndSettle();

    // Verifikasi hasil nilai kembalian dialog bernilai true
    expect(confirmed, isTrue);
  });

  testWidgets('AppDialog.delete renders danger styling and destructive intent',
      (tester) async {
    bool? confirmed;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                confirmed = await AppDialog.delete(
                  context,
                  title: 'Hapus Akun Mandiri?',
                  message: 'Seluruh transaksi akan tetap tersimpan aman.',
                  confirmLabel: 'Hapus Akun',
                );
              },
              child: const Text('Hapus Akun'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Hapus Akun'));
    await tester.pumpAndSettle();

    expect(find.text('Hapus Akun Mandiri?'), findsOneWidget);
    expect(find.text('Hapus Akun'), findsWidgets);

    // Tap tombol Batal
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(confirmed, isFalse);
  });

  testWidgets('AppSnackBar renders floating snackbar with icon and message',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                AppSnackBar.showSuccess(
                  context,
                  'Data berhasil disimpan dengan aman!',
                );
              },
              child: const Text('Tampilkan SnackBar'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tampilkan SnackBar'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Data berhasil disimpan dengan aman!'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets(
      'AppSnackBar in ShellRoute appears above FloatingBottomBar and auto-dismisses even with accessibleNavigation',
      (tester) async {
    var undoPressed = false;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(accessibleNavigation: true),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            extendBody: true,
            bottomNavigationBar: const FloatingBottomBar(selectedIndex: 1),
            body: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      AppSnackBar.show(
                        context,
                        message: 'Transaksi dihapus',
                        actionLabel: 'Urungkan',
                        duration: const Duration(milliseconds: 1000),
                        onAction: () => undoPressed = true,
                      );
                    },
                    child: const Text('Hapus'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Hapus'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final snackBarFinder = find.byType(SnackBar);
    final bottomBarFinder = find.byType(FloatingBottomBar);
    expect(snackBarFinder, findsOneWidget);
    expect(find.text('Urungkan'), findsOneWidget);

    // SnackBar harus berada di atas FloatingBottomBar (tidak tertutup)
    final snackBarRect = tester.getRect(snackBarFinder);
    final bottomBarRect = tester.getRect(bottomBarFinder);
    expect(snackBarRect.bottom, lessThanOrEqualTo(bottomBarRect.top));

    // Harus otomatis hilang setelah durasi habis meski accessibleNavigation=true
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(undoPressed, isFalse);
  });
}
