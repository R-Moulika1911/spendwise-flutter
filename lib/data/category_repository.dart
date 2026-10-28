import '../models/category.dart';
import '../utils/constants.dart';
import 'database_helper.dart';

class CategoryRepository {
  CategoryRepository({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<List<ExpenseCategory>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('categories', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(ExpenseCategory.fromMap).toList();
  }

  Future<ExpenseCategory?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ExpenseCategory.fromMap(rows.first);
  }

  Future<void> insert(ExpenseCategory category) async {
    final db = await _db.database;
    await db.insert('categories', category.toMap());
  }

  Future<void> update(ExpenseCategory category) async {
    final db = await _db.database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<DeleteCategoryResult> delete(String id) async {
    final db = await _db.database;
    final category = await getById(id);
    if (category == null) {
      return DeleteCategoryResult.notFound;
    }
    if (category.isDefault) {
      return DeleteCategoryResult.isDefault;
    }

    final countRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM expenses WHERE categoryId = ?',
      [id],
    );
    final count = (countRows.first['c'] as int?) ?? 0;

    if (count > 0) {
      await db.update(
        'expenses',
        {'categoryId': AppConstants.otherCategoryId},
        where: 'categoryId = ?',
        whereArgs: [id],
      );
    }

    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    return count > 0
        ? DeleteCategoryResult.movedToOther
        : DeleteCategoryResult.deleted;
  }
}

enum DeleteCategoryResult {
  deleted,
  movedToOther,
  isDefault,
  notFound,
}
