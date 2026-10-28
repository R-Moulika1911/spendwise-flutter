import 'constants.dart';

class Validators {
  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid number';
    }
    if (parsed <= 0) {
      return 'Amount must be greater than 0';
    }
    final parts = value.trim().split('.');
    if (parts.length == 2 && parts[1].length > 2) {
      return 'Use up to 2 decimal places';
    }
    return null;
  }

  static String? category(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) {
      return 'Please select a category';
    }
    return null;
  }

  static String? date(DateTime? date) {
    if (date == null) return 'Date is required';
    final today = DateTime.now();
    final endOfToday = DateTime(today.year, today.month, today.day, 23, 59, 59);
    if (date.isAfter(endOfToday)) {
      return 'Date cannot be in the future';
    }
    return null;
  }

  static String? note(String? value) {
    if (value != null && value.length > AppConstants.noteMaxLength) {
      return 'Note must be ${AppConstants.noteMaxLength} characters or less';
    }
    return null;
  }

  static String? categoryName(String? value, {List<String> existingNames = const [], String? excludeId}) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    final trimmed = value.trim();
    if (trimmed.length > AppConstants.categoryNameMaxLength) {
      return 'Max ${AppConstants.categoryNameMaxLength} characters';
    }
    final duplicate = existingNames.any(
      (n) => n.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) {
      return 'Category name already exists';
    }
    return null;
  }

  /// Pure helpers used by unit tests / summary logic.
  static double monthlyTotal(Iterable<double> amounts) =>
      amounts.fold(0.0, (sum, a) => sum + a);

  static Map<String, double> groupByCategory(
    Iterable<({String categoryId, double amount})> items,
  ) {
    final map = <String, double>{};
    for (final item in items) {
      map[item.categoryId] = (map[item.categoryId] ?? 0) + item.amount;
    }
    return map;
  }

  static Map<String, double> categoryPercentages(Map<String, double> totals) {
    final sum = totals.values.fold(0.0, (a, b) => a + b);
    if (sum <= 0) return {for (final k in totals.keys) k: 0.0};
    return {
      for (final e in totals.entries) e.key: (e.value / sum) * 100,
    };
  }
}
