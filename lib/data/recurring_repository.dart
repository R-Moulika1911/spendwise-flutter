import 'package:sqflite/sqflite.dart';

import '../models/recurring_expense.dart';
import 'database_helper.dart';

class RecurringRepository {
  RecurringRepository({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<List<RecurringExpense>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(
      'recurring_expenses',
      orderBy: 'nextRun ASC',
    );
    return rows.map(RecurringExpense.fromMap).toList();
  }

  Future<List<RecurringExpense>> getActiveDue(DateTime now) async {
    final db = await _db.database;
    final rows = await db.query(
      'recurring_expenses',
      where: 'isActive = 1 AND nextRun <= ?',
      whereArgs: [now.toIso8601String()],
    );
    return rows.map(RecurringExpense.fromMap).toList();
  }

  Future<void> insert(RecurringExpense item) async {
    final db = await _db.database;
    await db.insert('recurring_expenses', item.toMap());
  }

  Future<void> update(RecurringExpense item) async {
    final db = await _db.database;
    await db.update(
      'recurring_expenses',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('recurring_expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertAll(List<RecurringExpense> items) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'recurring_expenses',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
