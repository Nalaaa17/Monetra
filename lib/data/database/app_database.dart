import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'seed_data.dart';

class AppDatabase {
  static const String _dbName = 'monetra.db';
  static const int _dbVersion = 1;

  static Database? _database;
  static Future<Database>? _initFuture;
  static String? testDbPath;

  static Future<Database> get instance async {
    if (_database != null) return _database!;
    _initFuture ??= _initDatabase();
    try {
      final db = await _initFuture!;
      _database = db;
      return db;
    } catch (e) {
      _initFuture = null;
      rethrow;
    }
  }

  static Future<Database> _initDatabase() async {
    // Inisialisasi FFI jika dijalankan di platform desktop (Windows / Linux)
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    if (testDbPath != null) {
      dbPath = testDbPath!;
    } else if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      final docDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(docDir.path, 'Monetra', _dbName);
      final dir = Directory(p.dirname(dbPath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } else {
      final databasesPath = await getDatabasesPath();
      dbPath = p.join(databasesPath, _dbName);
    }

    final db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
    );

    // Pastikan tabel goals dan goal_contributions ada jika db sudah pernah dibuat sebelumnya
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

    // Pastikan kolom category (harian / tabungan) ada di tabel accounts
    try {
      await db.execute("ALTER TABLE accounts ADD COLUMN category TEXT DEFAULT 'harian'");
      await db.execute("UPDATE accounts SET category = 'tabungan' WHERE LOWER(name) LIKE '%seabank%'");
    } catch (_) {}

    // Pastikan kolom logoKey ada di tabel accounts
    try {
      await db.execute("ALTER TABLE accounts ADD COLUMN logoKey TEXT");
    } catch (_) {}

    // Pastikan kolom sourceAccountId dan isRealized ada di goal_contributions
    try {
      await db.execute('ALTER TABLE goal_contributions ADD COLUMN sourceAccountId INTEGER');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE goal_contributions ADD COLUMN isRealized INTEGER NOT NULL DEFAULT 0');
    } catch (_) {}

    try {
      await db.execute('''
        UPDATE goal_contributions
        SET sourceAccountId = (SELECT sourceAccountId FROM goals WHERE goals.id = goal_contributions.goalId)
        WHERE sourceAccountId IS NULL
      ''');
    } catch (_) {}

    // Pastikan tabel app_settings ada untuk menyimpan preferensi lokal (tema, auto-backup)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Pastikan tabel recurring_transactions ada pada database lama maupun baru
    await _ensureRecurringTable(db);

    // Pastikan tabel category_budgets ada
    await _ensureBudgetTable(db);

    // Pastikan tabel debts & investments ada
    await _ensureDebtsAndInvestmentsTables(db);

    return db;
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

  static bool get isOpen => _database != null;

  static Future<String?> getSetting(String key) async {
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

  static Future<void> setSetting(String key, String value) async {
    final db = await instance;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
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

    // 7. Table: app_settings
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 8. Table: recurring_transactions
    await _ensureRecurringTable(db);

    // 9. Table: category_budgets
    await _ensureBudgetTable(db);

    // 10. Table: debts & investments
    await _ensureDebtsAndInvestmentsTables(db);

    // Seed Data Awal
    await _seedInitialData(db);
  }

  static Future<void> _seedInitialData(Database db) async {
    final batch = db.batch();

    for (final account in SeedData.defaultAccounts) {
      batch.insert('accounts', account.toMap());
    }

    for (final category in SeedData.defaultCategories) {
      batch.insert('categories', category.toMap());
    }

    await batch.commit(noResult: true);
  }

  /// Tutup database (berguna saat test atau reset)
  static Future<void> close() async {
    if (_initFuture != null) {
      try {
        _database ??= await _initFuture;
      } catch (_) {}
      _initFuture = null;
    }
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
