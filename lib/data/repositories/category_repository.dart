import '../database/app_database.dart';
import '../models/category.dart';

class CategoryRepository {
  Future<List<Category>> getAllCategories({String? type, bool onlyActive = true}) async {
    final db = await AppDatabase.instance;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (onlyActive) {
      whereClauses.add('isActive = 1');
    }
    if (type != null) {
      whereClauses.add('type = ?');
      whereArgs.add(type);
    }

    final maps = await db.query(
      'categories',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'id ASC',
    );

    return maps.map((e) => Category.fromMap(e)).toList();
  }

  Future<Category?> getCategoryById(int id) async {
    final db = await AppDatabase.instance;
    final maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  Future<int> insertCategory(Category category) async {
    final db = await AppDatabase.instance;
    return await db.insert('categories', category.toMap());
  }

  Future<int> updateCategory(Category category) async {
    final db = await AppDatabase.instance;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> toggleActive(int id, bool isActive) async {
    final db = await AppDatabase.instance;
    return await db.update(
      'categories',
      {'isActive': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

