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
  static String? testDbPath;

  static Future<Database> get instance async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
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
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (goalId) REFERENCES goals(id) ON DELETE CASCADE
      )
    ''');

    return db;
  }

  static Future<void> _onCreate(Database db, int version) async {
    // 1. Table: accounts
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        colorHex TEXT NOT NULL,
        iconCodePoint INTEGER NOT NULL,
        initialBalance INTEGER NOT NULL DEFAULT 0,
        isArchived INTEGER NOT NULL DEFAULT 0,
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
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (goalId) REFERENCES goals(id) ON DELETE CASCADE
      )
    ''');

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
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
