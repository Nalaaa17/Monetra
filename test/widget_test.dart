import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/app.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.testDbPath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.close();
  });

  testWidgets('Monetra app smoke test (Splash to Home)', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MonetraApp(),
      ),
    );
    await tester.pump();

    // 1. Awal aplikasi menampilkan Splash Screen dengan Logo & Branding
    expect(find.text('Monetra'), findsOneWidget);
    expect(find.text('Pencatatan Keuangan Pribadi'), findsOneWidget);

    // 2. Animasi splash selesai (1.6 detik) dan otomatis berpindah ke Home Screen
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();

    // 3. Verifikasi Home Screen
    expect(find.text('• Halo!'), findsOneWidget);
    expect(find.text('Dompet & Rekening'), findsOneWidget);
  });
}
