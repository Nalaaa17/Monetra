import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/features/profile/providers/profile_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    AppDatabase.testDbPath = inMemoryDatabasePath;
    AppDatabase.testMetaDbPath = inMemoryDatabasePath;
    await AppDatabase.close();
  });

  tearDown(() async {
    await AppDatabase.close();
    AppDatabase.testDbPath = null;
    AppDatabase.testMetaDbPath = null;
  });

  group('Fase B: Profile Labels & UI State Tests', () {
    test('ProfileLabels mengembalikan label adaptif sesuai tipe profil', () {
      final personalProfile = ProfileModel(
        key: 'default',
        name: 'Pribadi',
        type: 'personal',
        iconCodePoint: 0xe491,
        colorHex: '0xFF10B981',
        createdAt: DateTime.now(),
      );

      final personalLabels = ProfileLabels(personalProfile);
      expect(personalLabels.income, 'Pemasukan');
      expect(personalLabels.expense, 'Pengeluaran');
      expect(personalLabels.netSummary, 'Sisa Uang');
      expect(personalLabels.isBusiness, isFalse);

      final businessProfile = ProfileModel(
        key: 'bisnis_1',
        name: 'Toko Senja',
        type: 'business',
        iconCodePoint: 0xe5e1,
        colorHex: '0xFF3B82F6',
        createdAt: DateTime.now(),
      );

      final businessLabels = ProfileLabels(businessProfile);
      expect(businessLabels.income, 'Omzet');
      expect(businessLabels.expense, 'Biaya Operasional');
      expect(businessLabels.netSummary, 'Laba Bersih');
      expect(businessLabels.isBusiness, isTrue);
    });

    test('Tidak dapat menghapus profil default Pribadi', () async {
      await AppDatabase.metaInstance;

      expect(
        () => AppDatabase.deleteProfile(AppDatabase.defaultProfileKey),
        throwsA(isA<Exception>()),
      );
    });

    test('Provider activeProfileProvider memuat profil aktif dengan benar', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final profile = await container.read(activeProfileProvider.future);
      expect(profile.key, AppDatabase.defaultProfileKey);
      expect(profile.name, 'Pribadi');
      expect(profile.isPersonal, isTrue);
    });
  });
}
