import '../models/expense.dart';
import 'database_helper.dart';

enum ExpenseSort { dateDesc, dateAsc, amountDesc, amountAsc }

class ExpenseFilter {
  final String? searchQuery;
  final String? categoryId;
  final DateTime? startDate;
  final DateTime? endDate;
  final ExpenseSort sort;

  const ExpenseFilter({
    this.searchQuery,
    this.categoryId,
    this.startDate,
    this.endDate,
    this.sort = ExpenseSort.dateDesc,
  });

  ExpenseFilter copyWith({
    String? searchQuery,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    ExpenseSort? sort,
    bool clearSearch = false,
    bool clearCategory = false,
    bool clearDates = false,
  }) {
    return ExpenseFilter(
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      sort: sort ?? this.sort,
    );
  }

  bool get hasActiveFilters =>
      (searchQuery != null && searchQuery!.trim().isNotEmpty) ||
      categoryId != null ||
      startDate != null ||
      endDate != null;
}

class ExpenseRepository {
  ExpenseRepository({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<List<Expense>> getAll({ExpenseFilter filter = const ExpenseFilter()}) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object?>[];

    final q = filter.searchQuery?.trim();
    if (q != null && q.isNotEmpty) {
      where.add('note LIKE ?');
      args.add('%$q%');
    }
    if (filter.categoryId != null) {
      where.add('categoryId = ?');
      args.add(filter.categoryId);
    }
    if (filter.startDate != null) {
      where.add('date >= ?');
      args.add(DateTime(
        filter.startDate!.year,
        filter.startDate!.month,
        filter.startDate!.day,
      ).toIso8601String());
    }
    if (filter.endDate != null) {
      final end = DateTime(
        filter.endDate!.year,
        filter.endDate!.month,
        filter.endDate!.day,
        23,
        59,
        59,
      );
      where.add('date <= ?');
      args.add(end.toIso8601String());
    }

    final orderBy = switch (filter.sort) {
      ExpenseSort.dateDesc => 'date DESC, createdAt DESC',
      ExpenseSort.dateAsc => 'date ASC, createdAt ASC',
      ExpenseSort.amountDesc => 'amount DESC',
      ExpenseSort.amountAsc => 'amount ASC',
    };

    final rows = await db.query(
      'expenses',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: orderBy,
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> getForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return getAll(
      filter: ExpenseFilter(startDate: start, endDate: end),
    );
  }

  Future<Expense?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Expense.fromMap(rows.first);
  }

  Future<void> insert(Expense expense) async {
    final db = await _db.database;
    await db.insert('expenses', expense.toMap());
  }

  Future<void> update(Expense expense) async {
    final db = await _db.database;
    await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> monthTotal(DateTime month) async {
    final expenses = await getForMonth(month);
    return expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
  }
}
