import '../database/app_database.dart';
import '../models/menu_item.dart';

class MenuRepository {
  Future<List<MenuItem>> getAllMenus() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('menus', orderBy: 'id DESC');
    return rows.map((r) => MenuItem.fromMap(r)).toList();
  }

  Future<MenuItem?> getMenuById(int id) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'menus',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MenuItem.fromMap(rows.first);
  }

  Future<MenuItem> insertMenu(MenuItem item) async {
    final db = await AppDatabase.instance;
    final id = await db.insert('menus', item.toMap());
    return item.copyWith(id: id);
  }

  Future<void> updateMenu(MenuItem item) async {
    if (item.id == null) return;
    final db = await AppDatabase.instance;
    await db.update(
      'menus',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteMenu(int id) async {
    final db = await AppDatabase.instance;
    await db.delete(
      'menus',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Catat penjualan cepat langsung dari katalog produk
  Future<int> recordQuickSale({
    required MenuItem item,
    required int quantity,
    required int accountId,
    int? categoryId,
    String? customNote,
  }) async {
    final db = await AppDatabase.instance;
    final totalAmount = item.sellingPrice * quantity;
    final note = customNote ?? 'Penjualan: ${item.name} (${quantity}x)';
    final now = DateTime.now().toIso8601String();

    return await db.transaction<int>((txn) async {
      final txId = await txn.insert('transactions', {
        'type': 'income',
        'amount': totalAmount,
        'accountId': accountId,
        'categoryId': categoryId,
        'note': note,
        'date': now,
        'createdAt': now,
      });
      return txId;
    });
  }
}
