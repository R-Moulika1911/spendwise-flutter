import '../data/expense_repository.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../utils/formatters.dart';

/// Runs agent tool calls against local SQLite (privacy: data stays on device).
class ExpenseAiTools {
  ExpenseAiTools({
    required ExpenseRepository repository,
    required List<ExpenseCategory> categories,
  })  : repo = repository,
        categories = List<ExpenseCategory>.unmodifiable(categories);

  final ExpenseRepository repo;
  final List<ExpenseCategory> categories;

  String? _categoryIdForName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final lower = name.trim().toLowerCase();
    for (final c in categories) {
      if (c.name.toLowerCase() == lower) return c.id;
    }
    return null;
  }

  String _nameForId(String id) {
    for (final c in categories) {
      if (c.id == id) return c.name;
    }
    return 'Other';
  }

  DateTime? _parseMonth(String? month) {
    if (month == null || !RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) {
      return null;
    }
    final parts = month.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  DateTime _monthOrNow(String? month) {
    return _parseMonth(month) ?? DateTime(DateTime.now().year, DateTime.now().month);
  }

  Future<Map<String, dynamic>> run(
    String name,
    Map<String, dynamic> args,
  ) async {
    switch (name) {
      case 'get_total':
        return _getTotal(args);
      case 'list_expenses':
        return _listExpenses(args);
      case 'compare_months':
        return _compareMonths(args);
      default:
        return {'error': 'Unknown tool: $name'};
    }
  }

  Future<Map<String, dynamic>> _getTotal(Map<String, dynamic> args) async {
    final month = _monthOrNow(args['month'] as String?);
    final categoryId = _categoryIdForName(args['category'] as String?);
    final expenses = await repo.getForMonth(month);
    final filtered = categoryId == null
        ? expenses
        : expenses.where((e) => e.categoryId == categoryId).toList();
    final total = filtered.fold<double>(0, (s, e) => s + e.amount);
    return {
      'month':
          '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}',
      'category': args['category'],
      'total': total,
      'count': filtered.length,
    };
  }

  Future<Map<String, dynamic>> _listExpenses(Map<String, dynamic> args) async {
    final month = _parseMonth(args['month'] as String?);
    final categoryId = _categoryIdForName(args['category'] as String?);
    var limit = (args['limit'] as num?)?.toInt() ?? 10;
    if (limit < 1) limit = 10;
    if (limit > 25) limit = 25;

    List<Expense> expenses;
    if (month != null) {
      expenses = await repo.getForMonth(month);
    } else {
      expenses = await repo.getAll(
        filter: const ExpenseFilter(sort: ExpenseSort.dateDesc),
      );
    }
    if (categoryId != null) {
      expenses = expenses.where((e) => e.categoryId == categoryId).toList();
    }
    expenses = expenses.take(limit).toList();

    return {
      'count': expenses.length,
      'expenses': expenses
          .map(
            (e) => {
              'amount': e.amount,
              'category': _nameForId(e.categoryId),
              'date': Formatters.dateOnly(e.date).toIso8601String().split('T').first,
              'note': e.note,
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _compareMonths(Map<String, dynamic> args) async {
    final a = _parseMonth(args['a'] as String?);
    final b = _parseMonth(args['b'] as String?);
    if (a == null || b == null) {
      return {'error': 'Both a and b must be YYYY-MM'};
    }

    Future<Map<String, dynamic>> summarize(DateTime month) async {
      final expenses = await repo.getForMonth(month);
      final total = expenses.fold<double>(0, (s, e) => s + e.amount);
      final byCat = <String, double>{};
      for (final e in expenses) {
        final name = _nameForId(e.categoryId);
        byCat[name] = (byCat[name] ?? 0) + e.amount;
      }
      final key =
          '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
      return {
        'month': key,
        'total': total,
        'byCategory': byCat.entries
            .map((e) => {'name': e.key, 'amount': e.value})
            .toList(),
      };
    }

    final sa = await summarize(a);
    final sb = await summarize(b);
    final ta = (sa['total'] as num).toDouble();
    final tb = (sb['total'] as num).toDouble();
    return {
      'a': sa,
      'b': sb,
      'difference': tb - ta,
      'percentChange': ta == 0 ? null : ((tb - ta) / ta) * 100,
    };
  }
}
