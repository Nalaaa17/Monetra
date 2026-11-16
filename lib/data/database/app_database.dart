import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/account.dart';
import '../models/profile_model.dart';
import 'seed_data.dart';

class AppDatabase {
  static const String _defaultDbName = 'monetra.db';
  static const String _metaDbName = 'monetra_meta.db';
  static const int _dbVersion = 1;

  static const String defaultProfileKey = 'default';

  // Kunci setting global yang disimpan di monetra_meta.db
  static const Set<String> _globalSettingKeys = {
    'theme_mode',
    'user_name',
    'onboarding_completed',
    'auto_backup_enabled',
    'last_auto_backup_date',
    'active_profile_key',
  };

  // State Database Meta
  static Database? _metaDatabase;
  static Future<Database>? _metaInitFuture;

  // State Database Profil Aktif
  static Database? _database;
  static Future<Database>? _initFuture;
  static String? _activeProfileKey;

  // Override untuk pengujian (unit/widget test)
  static String? testDbPath;
  static String? testMetaDbPath;

  /// Mendapatkan instance database meta global (`monetra_meta.db`)
  static Future<Database> get metaInstance async {
    if (_metaDatabase != null && _metaDatabase!.isOpen) return _metaDatabase!;
    _metaInitFuture ??= _initMetaDatabase();
    try {
      final db = await _metaInitFuture!;
      _metaDatabase = db;
      return db;
    } catch (e) {
      _metaInitFuture = null;
      rethrow;
    }
  }

  /// Mendapatkan instance database profil yang sedang aktif.
  /// 10 file repository memanggil getter ini secara transparan.
  static Future<Database> get instance async {
    if (_database != null && _database!.isOpen) return _database!;
    final activeKey = await getActiveProfileKey();
    _initFuture ??= _initProfileDatabase(activeKey);
    try {
      final db = await _initFuture!;
      _database = db;
      return db;
    } catch (e) {
      _initFuture = null;
      rethrow;
    }
  }

  /// Memeriksa apakah koneksi database profil aktif sedang terbuka
  static bool get isOpen => _database != null && _database!.isOpen;

  /// Memeriksa apakah database meta sedang terbuka
  static bool get isMetaOpen => _metaDatabase != null && _metaDatabase!.isOpen;

  /// Path resolver untuk file database
  static Future<String> _resolveDbPath(String fileName) async {
    if (fileName == _metaDbName && testMetaDbPath != null) {
      return testMetaDbPath!;
    }
    if (testDbPath != null) {
      if (testDbPath == inMemoryDatabasePath) {
        return inMemoryDatabasePath;
      }
      final dir = p.dirname(testDbPath!);
      return p.join(dir, fileName);
    }
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      final docDir = await getApplicationDocumentsDirectory();
      final fullPath = p.join(docDir.path, 'Monetra', fileName);
      final dir = Directory(p.dirname(fullPath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return fullPath;
    } else {
      final databasesPath = await getDatabasesPath();
      return p.join(databasesPath, fileName);
    }
  }

  /// Inisialisasi Database Meta (`monetra_meta.db`)
  static Future<Database> _initMetaDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final metaPath = await _resolveDbPath(_metaDbName);
    final db = await openDatabase(
      metaPath,
      version: 1,
      onCreate: (db, version) async {
        await _createMetaTables(db);
      },
    );

    await _createMetaTables(db);

    // Cek apakah tabel profiles masih kosong
    final existingProfiles = await db.query('profiles');
    if (existingProfiles.isEmpty) {
      // 1. Buat profil bawaan 'Pribadi'
      await db.insert('profiles', {
        'key': defaultProfileKey,
        'name': 'Pribadi',
        'type': 'personal',
        'iconCodePoint': 0xe491, // Icons.person_rounded
        'colorHex': '0xFF10B981',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // 2. Set active profile default
      await db.insert(
        'app_settings',
        {'key': 'active_profile_key', 'value': defaultProfileKey},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 3. Migrasikan setting lama dari monetra.db ke meta
      await _migrateLegacySettingsToMeta(db);
    }

    return db;
  }

  static Future<void> _createMetaTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        iconCodePoint INTEGER NOT NULL,
        colorHex TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// Migrasi setting global dari file `monetra.db` lama ke `monetra_meta.db`
  static Future<void> _migrateLegacySettingsToMeta(Database metaDb) async {
    try {
      if (testDbPath == inMemoryDatabasePath) return;
      final defaultDbPath = await _resolveDbPath(_defaultDbName);
      final file = File(defaultDbPath);
      if (!await file.exists()) return;

      final oldDb = await openDatabase(defaultDbPath);
      final tables = await oldDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='app_settings'",
      );
      if (tables.isNotEmpty) {
        final rows = await oldDb.query('app_settings');
        for (final row in rows) {
          final k = row['key'] as String;
          final v = row['value'] as String;
          if (_globalSettingKeys.contains(k)) {
            await metaDb.insert(
              'app_settings',
              {'key': k, 'value': v},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            try {
              await oldDb.delete('app_settings', where: 'key = ?', whereArgs: [k]);
            } catch (_) {}
          }
        }
      }
      await oldDb.close();
    } catch (e) {
      debugPrint('Legacy settings migration note: $e');
    }
  }

  /// Mengambil key profil yang sedang aktif (default: 'default')
  static Future<String> getActiveProfileKey() async {
    if (_activeProfileKey != null) return _activeProfileKey!;
    try {
      final metaDb = await metaInstance;
      final rows = await metaDb.query(
        'app_settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['active_profile_key'],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        _activeProfileKey = rows.first['value'] as String?;
      }
    } catch (_) {}
    _activeProfileKey ??= defaultProfileKey;
    return _activeProfileKey!;
  }

  /// Mendapatkan nama file database fisik berdasarkan key profil
  static String getProfileDbFileName(String profileKey) {
    if (profileKey == defaultProfileKey || profileKey.isEmpty) {
      return _defaultDbName;
    }
    return 'monetra_$profileKey.db';
  }

  /// Inisialisasi Database Profil Spesifik
  static Future<Database> _initProfileDatabase(String profileKey) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final fileName = getProfileDbFileName(profileKey);
    final dbPath = await _resolveDbPath(fileName);

    final db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _onCreateProfileDb(db, version, profileKey);
      },
    );

    // Pastikan integritas skema tabel jika DB sudah pernah dibuka
    await _ensureProfileSchema(db);

    return db;
  }

  /// Pembuatan tabel skema profil baru
  static Future<void> _onCreateProfileDb(
    Database db,
    int version,
    String profileKey,
  ) async {
    // 1. Table: accounts
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'harian',
        colorHex TEXT NOT NULL,
        iconCodePoint INTEGER NOT NULL,
        initialBalance INTEGER NOT NULL DEFAULT 0,
        isArchived INTEGER NOT NULL DEFAULT 0,
        logoKey TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // 2. Table: categories
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        iconCodePoint INTEGER NOT NULL,
        colorHex TEXT NOT NULL,
        type TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 3. Table: transactions
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        accountId INTEGER NOT NULL,
        categoryId INTEGER,
        note TEXT,
        date TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        imagePath TEXT,
        FOREIGN KEY (accountId) REFERENCES accounts(id) ON DELETE CASCADE,
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    // 4. Table: transfers
    await db.execute('''
      CREATE TABLE transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fromAccountId INTEGER NOT NULL,
        toAccountId INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (fromAccountId) REFERENCES accounts(id) ON DELETE CASCADE,
        FOREIGN KEY (toAccountId) REFERENCES accounts(id) ON DELETE CASCADE
      )
    ''');

    // 5. Table: goals
    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        targetAmount INTEGER NOT NULL,
        collectedAmount INTEGER NOT NULL DEFAULT 0,
        deadline TEXT NOT NULL,
        repeatMonthly INTEGER NOT NULL DEFAULT 0,
        sourceAccountId INTEGER NOT NULL,
        reminderEnabled INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'active',
        createdAt TEXT NOT NULL,
        FOREIGN KEY (sourceAccountId) REFERENCES accounts(id) ON DELETE CASCADE
      )
    ''');

    // 6. Table: goal_contributions
    await db.execute('''
      CREATE TABLE goal_contributions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goalId INTEGER NOT NULL,
        sourceAccountId INTEGER,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        isRealized INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (goalId) REFERENCES goals(id) ON DELETE CASCADE,
        FOREIGN KEY (sourceAccountId) REFERENCES accounts(id) ON DELETE CASCADE
      )
    ''');

    // 7. Table: app_settings (lokal per profil, misal: overall_monthly_budget)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 8. Recurring transactions
    await _ensureRecurringTable(db);

    // 9. Category budgets
    await _ensureBudgetTable(db);

    // 10. Debts & Investments
    await _ensureDebtsAndInvestmentsTables(db);

    // 11. Menus (Katalog Produk & HPP Bisnis)
    await _ensureMenusTable(db);

    // 12. Vacations (Kantong & Anggaran Liburan)
    await _ensureVacationsTable(db);

    // Seed Data Awal sesuai tipe profil
    await _seedInitialDataForProfile(db, profileKey);
  }

  /// Memastikan seluruh skema tabel profil mutakhir
  static Future<void> _ensureProfileSchema(Database db) async {
    // Goals & Goal Contributions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        targetAmount INTEGER NOT NULL,
        collectedAmount INTEGER NOT NULL DEFAULT 0,
        deadline TEXT NOT NULL,
        repeatMonthly INTEGER NOT NULL DEFAULT 0,
        sourceAccountId INTEGER NOT NULL,
        reminderEnabled INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'active',
        createdAt TEXT NOT NULL,
        FOREIGN KEY (sourceAccountId) REFERENCES accounts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_contributions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goalId INTEGER NOT NULL,
        sourceAccountId INTEGER,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        isRealized INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (goalId) REFERENCES goals(id) ON DELETE CASCADE,
        FOREIGN KEY (sourceAccountId) REFERENCES accounts(id) ON DELETE CASCADE
      )
    ''');

    try {
      await db.execute("ALTER TABLE accounts ADD COLUMN category TEXT DEFAULT 'harian'");
    } catch (_) {}

    try {
      await db.execute("ALTER TABLE accounts ADD COLUMN logoKey TEXT");
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE goal_contributions ADD COLUMN sourceAccountId INTEGER');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE goal_contributions ADD COLUMN isRealized INTEGER NOT NULL DEFAULT 0');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _ensureRecurringTable(db);
    await _ensureBudgetTable(db);
    await _ensureDebtsAndInvestmentsTables(db);
    await _ensureTransactionColumns(db);
    await _ensureMenusTable(db);
    await _ensureVacationsTable(db);
  }

  static Future<void> _ensureTransactionColumns(Database db) async {
    try {
      final cols = await db.rawQuery('PRAGMA table_info(transactions)');
      final hasImagePath = cols.any((c) => c['name'] == 'imagePath');
      if (!hasImagePath) {
        await db.execute('ALTER TABLE transactions ADD COLUMN imagePath TEXT');
      }
      final hasVacationId = cols.any((c) => c['name'] == 'vacationId');
      if (!hasVacationId) {
        await db.execute('ALTER TABLE transactions ADD COLUMN vacationId INTEGER');
      }
    } catch (_) {}
  }

  static Future<void> _ensureVacationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vacations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        destination TEXT,
        targetBudget INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        colorHex TEXT NOT NULL DEFAULT '0xFF0284C7',
        iconCodePoint INTEGER NOT NULL DEFAULT 0xe5e1,
        startDate TEXT,
        endDate TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS vacation_allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vacationId INTEGER NOT NULL,
        sourceAccountId INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (vacationId) REFERENCES vacations(id) ON DELETE CASCADE,
        FOREIGN KEY (sourceAccountId) REFERENCES accounts(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _ensureDebtsAndInvestmentsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        personName TEXT NOT NULL,
        type TEXT NOT NULL,
        totalAmount INTEGER NOT NULL,
        paidAmount INTEGER NOT NULL DEFAULT 0,
        dueDate TEXT,
        note TEXT,
        isSettled INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS debt_contributions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debtId INTEGER NOT NULL,
        sourceAccountId INTEGER,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        isRealized INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (debtId) REFERENCES debts(id) ON DELETE CASCADE,
        FOREIGN KEY (sourceAccountId) REFERENCES accounts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS investments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        platform TEXT NOT NULL,
        category TEXT NOT NULL,
        initialAmount INTEGER NOT NULL,
        currentAmount INTEGER NOT NULL,
        logoKey TEXT,
        note TEXT,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _ensureBudgetTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS category_budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryId INTEGER NOT NULL UNIQUE,
        monthlyLimit INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _ensureRecurringTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        accountId INTEGER NOT NULL,
        categoryId INTEGER,
        note TEXT,
        frequency TEXT NOT NULL,
        dayOfMonth INTEGER NOT NULL DEFAULT 1,
        dayOfWeek INTEGER NOT NULL DEFAULT 1,
        nextRunDate TEXT NOT NULL,
        lastRunDate TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (accountId) REFERENCES accounts(id) ON DELETE CASCADE,
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recurring_active_next
      ON recurring_transactions(isActive, nextRunDate)
    ''');
  }

  static Future<void> _ensureMenusTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS menus (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'fnb',
        costPrice INTEGER NOT NULL DEFAULT 0,
        sellingPrice INTEGER NOT NULL DEFAULT 0,
        ingredientsJson TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  /// Seeding data awal berdasarkan tipe profil
  static Future<void> _seedInitialDataForProfile(Database db, String profileKey) async {
    String profileType = 'personal';
    try {
      final metaDb = await metaInstance;
      final rows = await metaDb.query(
        'profiles',
        columns: ['type'],
        where: 'key = ?',
        whereArgs: [profileKey],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        profileType = rows.first['type'] as String? ?? 'personal';
      }
    } catch (_) {}

    final batch = db.batch();

    if (profileType == 'business') {
      for (final account in SeedData.defaultBusinessAccounts) {
        batch.insert('accounts', account.toMap());
      }
      for (final category in SeedData.defaultBusinessCategories) {
        batch.insert('categories', category.toMap());
      }
    } else {
      for (final account in SeedData.defaultAccounts) {
        batch.insert('accounts', account.toMap());
      }
      for (final category in SeedData.defaultCategories) {
        batch.insert('categories', category.toMap());
      }
    }

    await batch.commit(noResult: true);
  }

  /// Berpindah profil aktif: menutup DB profil lama & membuka DB profil target
  static Future<void> switchProfile(String targetKey) async {
    final currentKey = await getActiveProfileKey();
    if (currentKey == targetKey && _database != null && _database!.isOpen) {
      return;
    }

    // 1. Tutup database profil aktif saat ini secara bersih
    await closeProfileDb();

    // 2. Simpan profil aktif baru ke monetra_meta.db
    await setGlobalSetting('active_profile_key', targetKey);
    _activeProfileKey = targetKey;

    // 3. Buka database profil baru
    _initFuture = _initProfileDatabase(targetKey);
    _database = await _initFuture!;
  }

  /// Menutup database profil yang sedang aktif tanpa menutup meta DB
  static Future<void> closeProfileDb() async {
    if (_initFuture != null) {
      try {
        _database ??= await _initFuture;
      } catch (_) {}
      _initFuture = null;
    }
    if (_database != null) {
      if (_database!.isOpen) {
        await _database!.close();
      }
      _database = null;
    }
  }

  /// Menutup seluruh koneksi database (profil aktif & meta DB)
  static Future<void> close() async {
    await closeProfileDb();
    if (_metaInitFuture != null) {
      try {
        _metaDatabase ??= await _metaInitFuture;
      } catch (_) {}
      _metaInitFuture = null;
    }
    if (_metaDatabase != null) {
      if (_metaDatabase!.isOpen) {
        await _metaDatabase!.close();
      }
      _metaDatabase = null;
    }
    _activeProfileKey = null;
  }

  // --------------------------------------------------------------------------
  // Manajemen Pengaturan (Settings): Pintar Merutekan Global vs Profil
  // --------------------------------------------------------------------------

  /// Mengambil pengaturan. Jika key adalah setting global (tema, onboarding, autobackup),
  /// diambil dari `monetra_meta.db`. Jika key profil (overall_monthly_budget), diambil dari DB profil aktif.
  static Future<String?> getSetting(String key) async {
    if (_globalSettingKeys.contains(key)) {
      return getGlobalSetting(key);
    }
    final db = await instance;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Menyimpan pengaturan. Merutekan otomatis ke meta DB atau DB profil aktif.
  static Future<void> setSetting(String key, String value) async {
    if (_globalSettingKeys.contains(key)) {
      return setGlobalSetting(key, value);
    }
    final db = await instance;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Mengambil pengaturan spesifik dari DB Meta global
  static Future<String?> getGlobalSetting(String key) async {
    final metaDb = await metaInstance;
    final rows = await metaDb.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Menyimpan pengaturan spesifik ke DB Meta global
  static Future<void> setGlobalSetting(String key, String value) async {
    final metaDb = await metaInstance;
    await metaDb.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --------------------------------------------------------------------------
  // Operasi Profil (CRUD)
  // --------------------------------------------------------------------------

  /// Mengambil semua profil yang terdaftar
  static Future<List<ProfileModel>> getAllProfiles() async {
    final metaDb = await metaInstance;
    final rows = await metaDb.query('profiles', orderBy: 'id ASC');
    return rows.map((r) => ProfileModel.fromMap(r)).toList();
  }

  /// Mengambil profil berdasarkan key
  static Future<ProfileModel?> getProfileByKey(String key) async {
    final metaDb = await metaInstance;
    final rows = await metaDb.query(
      'profiles',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProfileModel.fromMap(rows.first);
  }

  /// Membuat profil baru
  static Future<ProfileModel> createProfile(ProfileModel profile) async {
    final metaDb = await metaInstance;
    final id = await metaDb.insert('profiles', profile.toMap());
    return profile.copyWith(id: id);
  }

  /// Memperbarui profil (nama, ikon, warna)
  static Future<void> updateProfile(ProfileModel profile) async {
    final metaDb = await metaInstance;
    await metaDb.update(
      'profiles',
      profile.toMap(),
      where: 'key = ?',
      whereArgs: [profile.key],
    );
  }

  /// Menghapus profil (tidak dapat menghapus profil 'default' / Pribadi)
  static Future<void> deleteProfile(String key) async {
    if (key == defaultProfileKey) {
      throw Exception('Profil default (Pribadi) tidak dapat dihapus');
    }
    final metaDb = await metaInstance;
    final currentActive = await getActiveProfileKey();
    if (currentActive == key) {
      await switchProfile(defaultProfileKey);
    }

    await metaDb.delete('profiles', where: 'key = ?', whereArgs: [key]);

    // Hapus file fisik database jika bukan in-memory test
    if (testDbPath != inMemoryDatabasePath) {
      try {
        final fileName = getProfileDbFileName(key);
        final filePath = await _resolveDbPath(fileName);
        await deleteDatabase(filePath);
      } catch (e) {
        debugPrint('Error deleting profile DB file: $e');
      }
    }
  }

  /// Membuka atau mendapatkan database untuk profil tertentu secara aman
  static Future<Database> getDatabaseForProfile(String profileKey) async {
    final currentActive = await getActiveProfileKey();
    if (currentActive == profileKey && _database != null && _database!.isOpen) {
      return _database!;
    }
    final fileName = getProfileDbFileName(profileKey);
    final dbPath = await _resolveDbPath(fileName);
    final db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _onCreateProfileDb(db, version, profileKey);
      },
    );
    await _ensureProfileSchema(db);
    return db;
  }

  /// Mengambil daftar akun aktif untuk profil tertentu (tanpa harus switch UI)
  static Future<List<Account>> getAccountsForProfile(String profileKey) async {
    final db = await getDatabaseForProfile(profileKey);
    final rows = await db.query(
      'accounts',
      where: 'isArchived = 0',
      orderBy: 'id ASC',
    );
    return rows.map((r) => Account.fromMap(r)).toList();
  }

  /// Mengganti akun awal profil aktif dengan akun yang dipilih pengguna saat onboarding (jika belum ada transaksi)
  static Future<void> setupInitialAccounts(List<Account> chosenAccounts) async {
    if (chosenAccounts.isEmpty) return;
    final db = await instance;
    final countRes =
        await db.rawQuery('SELECT COUNT(*) as c FROM transactions');
    final countTx =
        countRes.isNotEmpty ? (countRes.first['c'] as int? ?? 0) : 0;
    if (countTx == 0) {
      await db.transaction((txn) async {
        await txn.delete('accounts');
        final batch = txn.batch();
        for (final acc in chosenAccounts) {
          batch.insert('accounts', acc.toMap());
        }
        await batch.commit(noResult: true);
      });
    }
  }

  /// Menyelesaikan setup awal Onboarding: fokus profil, dompet pilihan, dan nama pengguna
  static Future<void> completeOnboardingSetup({
    required String profileChoice, // 'personal', 'business', 'both'
    required List<Account> chosenAccounts,
    required String userName,
  }) async {
    final metaDb = await metaInstance;
    final finalName =
        userName.trim().isNotEmpty ? userName.trim() : 'Sahabat Monetra';

    // 1. Simpan nama pengguna & status onboarding
    await setGlobalSetting('onboarding_completed', 'true');
    await setGlobalSetting('user_name', finalName);
    await setSetting('user_name', finalName);

    // 2. Konfigurasi profil & akun awal
    if (profileChoice == 'business') {
      // Ubah profil default menjadi profil bisnis
      await metaDb.update(
        'profiles',
        {
          'name': 'Bisnis',
          'type': 'business',
          'iconCodePoint': 0xe5ce, // Icons.storefront_rounded
          'colorHex': '0xFF3B82F6',
        },
        where: 'key = ?',
        whereArgs: [defaultProfileKey],
      );
      await setupInitialAccounts(chosenAccounts);
    } else if (profileChoice == 'both') {
      // Profil default 'pribadi' menggunakan akun pilihan personal
      await setupInitialAccounts(chosenAccounts);

      // Tambahkan profil 'bisnis' jika belum ada
      final existing = await metaDb.query(
        'profiles',
        where: 'key = ?',
        whereArgs: ['bisnis'],
        limit: 1,
      );
      if (existing.isEmpty) {
        await metaDb.insert('profiles', {
          'key': 'bisnis',
          'name': 'Bisnis / Toko',
          'type': 'business',
          'iconCodePoint': 0xe5ce,
          'colorHex': '0xFF3B82F6',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    } else {
      // 'personal'
      await setupInitialAccounts(chosenAccounts);
    }
  }
}
