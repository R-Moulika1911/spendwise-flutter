import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/expense_repository.dart';
import '../models/expense.dart';
import '../utils/formatters.dart';

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider({ExpenseRepository? repository})
      : _repo = repository ?? ExpenseRepository();

  final ExpenseRepository _repo;
  final _uuid = const Uuid();

  List<Expense> _expenses = [];
  ExpenseFilter _filter = const ExpenseFilter();
  bool _loading = false;
  String? _error;
  Expense? _lastDeleted;

  List<Expense> get expenses => List.unmodifiable(_expenses);
  ExpenseFilter get filter => _filter;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get canUndo => _lastDeleted != null;

  double get filteredTotal =>
      _expenses.fold(0.0, (sum, e) => sum + e.amount);

  double totalForMonth(DateTime month) {
    return _expenses
        .where((e) => Formatters.isSameMonth(e.date, month))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  Map<DateTime, List<Expense>> get groupedByDate {
    final map = <DateTime, List<Expense>>{};
    for (final expense in _expenses) {
      final key = Formatters.dateOnly(expense.date);
      map.putIfAbsent(key, () => []).add(expense);
    }
    final sortedKeys = map.keys.toList()
      ..sort((a, b) {
        switch (_filter.sort) {
          case ExpenseSort.dateAsc:
            return a.compareTo(b);
          case ExpenseSort.dateDesc:
          case ExpenseSort.amountAsc:
          case ExpenseSort.amountDesc:
            return b.compareTo(a);
        }
      });
    return {for (final k in sortedKeys) k: map[k]!};
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _expenses = await _repo.getAll(filter: _filter);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setFilter(ExpenseFilter filter) async {
    _filter = filter;
    await load();
  }

  Future<void> clearFilters() async {
    _filter = ExpenseFilter(sort: _filter.sort);
    await load();
  }

  Future<void> addExpense({
    required double amount,
    required String categoryId,
    required DateTime date,
    String? note,
  }) async {
    final now = DateTime.now();
    final expense = Expense(
      id: _uuid.v4(),
      amount: amount,
      categoryId: categoryId,
      date: Formatters.dateOnly(date),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _repo.insert(expense);
    await load();
  }

  /// Insert without reloading (used by recurring processor).
  Future<void> addExpenseDirect(Expense expense) async {
    await _repo.insert(expense);
  }

  Future<List<Expense>> getAllUnfiltered() {
    return _repo.getAll();
  }

  Future<double> monthTotalUnfiltered(DateTime month) {
    return _repo.monthTotal(month);
  }

  Future<void> updateExpense(Expense expense) async {
    final note = expense.note?.trim();
    final updated = Expense(
      id: expense.id,
      amount: expense.amount,
      categoryId: expense.categoryId,
      date: Formatters.dateOnly(expense.date),
      note: (note == null || note.isEmpty) ? null : note,
      createdAt: expense.createdAt,
      updatedAt: DateTime.now(),
    );
    await _repo.update(updated);
    await load();
  }

  Future<Expense?> deleteExpense(String id) async {
    final existing = _expenses.cast<Expense?>().firstWhere(
          (e) => e?.id == id,
          orElse: () => null,
        );
    if (existing == null) return null;
    _lastDeleted = existing;
    await _repo.delete(id);
    await load();
    return existing;
  }

  Future<void> undoDelete() async {
    final expense = _lastDeleted;
    if (expense == null) return;
    await _repo.insert(expense);
    _lastDeleted = null;
    await load();
  }

  Future<List<Expense>> expensesForMonth(DateTime month) {
    return _repo.getForMonth(month);
  }
}
