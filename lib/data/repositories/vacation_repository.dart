import '../database/app_database.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/vacation.dart';

class VacationRepository {
  /// Mengambil daftar trip liburan yang sedang aktif
  Future<List<VacationModel>> getActiveVacations() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'vacations',
      where: "status = 'active'",
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => VacationModel.fromMap(r)).toList();
  }

  /// Mengambil daftar trip liburan yang sudah selesai
  Future<List<VacationModel>> getCompletedVacations() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'vacations',
      where: "status = 'completed'",
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => VacationModel.fromMap(r)).toList();
  }

  /// Mengambil detail lengkap sebuah trip liburan beserta rincian bank dan transaksi
  Future<VacationDetail?> getVacationDetail(int vacationId) async {
    final db = await AppDatabase.instance;

    // 1. Ambil model vacation
    final vacRows = await db.query(
      'vacations',
      where: 'id = ?',
      whereArgs: [vacationId],
      limit: 1,
    );
    if (vacRows.isEmpty) return null;
    final vacation = VacationModel.fromMap(vacRows.first);

    // 2. Ambil semua alokasi rekening untuk liburan ini
    final allocRows = await db.rawQuery('''
      SELECT 
        va.sourceAccountId,
        COALESCE(SUM(va.amount), 0) as totalAllocated
      FROM vacation_allocations va
      WHERE va.vacationId = ?
      GROUP BY va.sourceAccountId
    ''', [vacationId]);

    final List<VacationAccountBreakdown> accounts = [];

    for (final row in allocRows) {
      final accountId = row['sourceAccountId'] as int;
      final allocated = (row['totalAllocated'] as num).toInt();

      // Ambil info rekening
      final accRows = await db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );
      if (accRows.isEmpty) continue;
      final account = Account.fromMap(accRows.first);

      // Hitung pengeluaran dari rekening ini khusus untuk liburan ini
      final spentRes = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) as totalSpent
        FROM transactions
        WHERE vacationId = ? AND accountId = ? AND type = 'expense'
      ''', [vacationId, accountId]);
      final spent = (spentRes.first['totalSpent'] as num?)?.toInt() ?? 0;

      accounts.add(VacationAccountBreakdown(
        account: account,
        allocatedAmount: allocated,
        spentAmount: spent,
      ));
    }

    // 3. Ambil seluruh transaksi liburan ini
    final txRows = await db.query(
      'transactions',
      where: 'vacationId = ?',
      whereArgs: [vacationId],
      orderBy: 'date DESC, id DESC',
    );
    final transactions = txRows.map((r) => TransactionModel.fromMap(r)).toList();

    return VacationDetail(
      vacation: vacation,
      accounts: accounts,
      transactions: transactions,
    );
  }

  /// Membuat trip liburan baru dan menyisihkan dana dari rekening-rekening yang dipilih
  Future<int> createVacation({
    required VacationModel vacation,
    required Map<int, int> accountAllocations, // accountId -> amount
  }) async {
    final db = await AppDatabase.instance;
    return await db.transaction((txn) async {
      // 1. Simpan trip liburan
      final vacationId = await txn.insert('vacations', vacation.toMap());

      // 2. Simpan alokasi dana per rekening
      for (final entry in accountAllocations.entries) {
        if (entry.value > 0) {
          final alloc = VacationAllocation(
            vacationId: vacationId,
            sourceAccountId: entry.key,
            amount: entry.value,
            createdAt: DateTime.now(),
          );
          await txn.insert('vacation_allocations', alloc.toMap());
        }
      }

      return vacationId;
    });
  }

  /// Menambah alokasi dana baru ke trip liburan yang sedang berjalan
  Future<void> addAllocation({
    required int vacationId,
    required int accountId,
    required int amount,
  }) async {
    if (amount <= 0) return;
    final db = await AppDatabase.instance;
    final alloc = VacationAllocation(
      vacationId: vacationId,
      sourceAccountId: accountId,
      amount: amount,
      createdAt: DateTime.now(),
    );
    await db.insert('vacation_allocations', alloc.toMap());
  }

  /// Mencatat transaksi pengeluaran khusus liburan
  Future<int> recordVacationExpense({
    required int vacationId,
    required int accountId,
    required int amount,
    int? categoryId,
    String? note,
    DateTime? date,
    String? imagePath,
  }) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now();
    final tx = TransactionModel(
      type: 'expense',
      amount: amount,
      accountId: accountId,
      categoryId: categoryId,
      note: note,
      date: date ?? now,
      createdAt: now,
      imagePath: imagePath,
      vacationId: vacationId,
    );
    return await db.insert('transactions', tx.toMap());
  }

  /// Menyelesaikan liburan (sisa dana yang belum terpakai otomatis dikembalikan ke saldo bebas)
  Future<void> completeVacation(int vacationId) async {
    final db = await AppDatabase.instance;
    await db.update(
      'vacations',
      {
        'status': 'completed',
        'endDate': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [vacationId],
    );
  }

  /// Menghapus trip liburan (melepas relasi transaksi agar riwayat pengeluaran tetap tercatat di akun)
  Future<void> deleteVacation(int vacationId) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      // Lepas relasi vacationId di transaksi
      await txn.update(
        'transactions',
        {'vacationId': null},
        where: 'vacationId = ?',
        whereArgs: [vacationId],
      );
      // Hapus alokasi
      await txn.delete(
        'vacation_allocations',
        where: 'vacationId = ?',
        whereArgs: [vacationId],
      );
      // Hapus liburan
      await txn.delete(
        'vacations',
        where: 'id = ?',
        whereArgs: [vacationId],
      );
    });
  }

  /// Menghitung sisa dana liburan aktif yang sedang terkunci dari rekening tertentu
  Future<int> calculateVacationAllocatedForAccount(int accountId) async {
    final db = await AppDatabase.instance;

    // 1. Total alokasi masuk dari rekening ini untuk semua liburan yang masih aktif
    final allocRes = await db.rawQuery('''
      SELECT COALESCE(SUM(va.amount), 0) as totalAllocated
      FROM vacation_allocations va
      JOIN vacations v ON va.vacationId = v.id
      WHERE va.sourceAccountId = ? AND v.status = 'active'
    ''', [accountId]);
    final totalAllocated = (allocRes.first['totalAllocated'] as num?)?.toInt() ?? 0;
    if (totalAllocated <= 0) return 0;

    // 2. Total pengeluaran yang sudah terjadi dari rekening ini di liburan aktif
    final spentRes = await db.rawQuery('''
      SELECT COALESCE(SUM(t.amount), 0) as totalSpent
      FROM transactions t
      JOIN vacations v ON t.vacationId = v.id
      WHERE t.accountId = ? AND t.type = 'expense' AND v.status = 'active'
    ''', [accountId]);
    final totalSpent = (spentRes.first['totalSpent'] as num?)?.toInt() ?? 0;

    final remaining = totalAllocated - totalSpent;
    return remaining > 0 ? remaining : 0;
  }

  /// Menghitung seluruh dana aktif yang terkunci di semua liburan
  Future<int> calculateTotalAllocatedInVacations() async {
    final db = await AppDatabase.instance;

    final allocRes = await db.rawQuery('''
      SELECT COALESCE(SUM(va.amount), 0) as totalAllocated
      FROM vacation_allocations va
      JOIN vacations v ON va.vacationId = v.id
      WHERE v.status = 'active'
    ''');
    final totalAllocated = (allocRes.first['totalAllocated'] as num?)?.toInt() ?? 0;
    if (totalAllocated <= 0) return 0;

    final spentRes = await db.rawQuery('''
      SELECT COALESCE(SUM(t.amount), 0) as totalSpent
      FROM transactions t
      JOIN vacations v ON t.vacationId = v.id
      WHERE t.type = 'expense' AND v.status = 'active'
    ''');
    final totalSpent = (spentRes.first['totalSpent'] as num?)?.toInt() ?? 0;

    final remaining = totalAllocated - totalSpent;
    return remaining > 0 ? remaining : 0;
  }
}
