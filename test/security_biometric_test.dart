import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/services/biometric_service.dart';
import 'package:monetra/features/security/screens/app_lock_screen.dart';
import 'package:monetra/features/settings/screens/security_settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.testDbPath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.close();
  });

  test(
    'BiometricService saves and reads settings from database correctly',
    () async {
      // Default should be false
      final defaultEnabled = await BiometricService.isBiometricLockEnabled();
      expect(defaultEnabled, false);

      // Set to true
      await BiometricService.setBiometricLockEnabled(true);
      final updated = await BiometricService.isBiometricLockEnabled();
      expect(updated, true);

      // Test lock on resume setting
      await BiometricService.setLockOnResumeEnabled(false);
      expect(await BiometricService.isLockOnResumeEnabled(), false);

      await BiometricService.setLockOnResumeEnabled(true);
      expect(await BiometricService.isLockOnResumeEnabled(), true);
    },
  );

  testWidgets('AppLockScreen renders correctly with fingerprint prompt', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AppLockScreen())),
    );
    await tester.pump();

    expect(find.text('Monetra Terkunci'), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
    expect(find.text('Pindai Ulang / Gunakan PIN'), findsOneWidget);
    expect(find.text('Privat & Terenkripsi di Perangkat'), findsOneWidget);
  });

  testWidgets('SecuritySettingsScreen displays options and hardware status', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SecuritySettingsScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keamanan & Biometrik'), findsOneWidget);
    expect(find.text('Kunci Sidik Jari / PIN'), findsOneWidget);
    expect(find.text('Tes Sensor Biometrik Sekarang'), findsOneWidget);
    expect(find.text('100% Privat & Aman'), findsOneWidget);
  });
}
