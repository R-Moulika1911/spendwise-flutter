import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/recurring_repository.dart';
import '../models/expense.dart';
import '../models/recurring_expense.dart';
import '../utils/formatters.dart';
import 'expense_provider.dart';

class RecurringProvider extends ChangeNotifier {
  RecurringProvider({RecurringRepository? repository})
      : _repo = repository ?? RecurringRepository();

  final RecurringRepository _repo;
  final _uuid = const Uuid();

  List<RecurringExpense> _items = [];
  bool _loading = false;

  List<RecurringExpense> get items => List.unmodifiable(_items);
  bool get isLoading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _items = await _repo.getAll();
    _loading = false;
    notifyListeners();
  }

  Future<void> add({
    required double amount,
    required String categoryId,
    String? note,
    required RecurrenceFrequency frequency,
    required DateTime startDate,
  }) async {
    final now = DateTime.now();
    final start = Formatters.dateOnly(startDate);
    final item = RecurringExpense(
      id: _uuid.v4(),
      amount: amount,
      categoryId: categoryId,
      note: note,
      frequency: frequency,
      startDate: start,
      nextRun: start,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.insert(item);
    await load();
  }

  Future<void> updateItem(RecurringExpense item) async {
    await _repo.update(item.copyWith(updatedAt: DateTime.now()));
    await load();
  }

  Future<void> toggleActive(RecurringExpense item) async {
    await updateItem(item.copyWith(isActive: !item.isActive));
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await load();
  }

  /// Creates due expense rows and advances nextRun.
  Future<int> processDue(ExpenseProvider expenseProvider) async {
    final now = DateTime.now();
    final due = await _repo.getActiveDue(now);
    var created = 0;

    for (var item in due) {
      var next = Formatters.dateOnly(item.nextRun);
      final today = Formatters.dateOnly(now);

      // Catch up missed occurrences (cap to avoid huge loops)
      var guard = 0;
      while (!next.isAfter(today) && guard < 36) {
        final stamp = DateTime.now();
        await expenseProvider.addExpenseDirect(
          Expense(
            id: _uuid.v4(),
            amount: item.amount,
            categoryId: item.categoryId,
            date: next,
            note: item.note == null || item.note!.isEmpty
                ? 'Recurring'
                : '${item.note} (recurring)',
            createdAt: stamp,
            updatedAt: stamp,
          ),
        );
        created++;
        next = Formatters.dateOnly(item.advance(next));
        guard++;
      }

      await _repo.update(
        item.copyWith(nextRun: next, updatedAt: DateTime.now()),
      );
    }

    if (due.isNotEmpty) {
      await load();
      await expenseProvider.load();
    }
    return created;
  }
}
