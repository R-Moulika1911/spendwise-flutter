/// Draft returned by `POST /ai/parse-expense` before the user confirms.
class ParsedExpense {
  final double amount;
  final String category;
  final DateTime date;
  final String? note;

  const ParsedExpense({
    required this.amount,
    required this.category,
    required this.date,
    this.note,
  });

  ParsedExpense copyWith({
    double? amount,
    String? category,
    DateTime? date,
    String? note,
    bool clearNote = false,
  }) {
    return ParsedExpense(
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  factory ParsedExpense.fromJson(Map<String, dynamic> json) {
    return ParsedExpense(
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String? ?? 'Other',
      // Calendar day only — avoid UTC shift from DateTime.parse("YYYY-MM-DD").
      date: _parseCalendarDate(json['date']) ?? _todayLocal(),
      note: json['note'] as String?,
    );
  }

  static DateTime _todayLocal() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Parses `YYYY-MM-DD` as a local calendar date (no timezone conversion).
  static DateTime? _parseCalendarDate(dynamic raw) {
    if (raw is! String) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw.trim());
    if (m == null) return null;
    final y = int.tryParse(m[1]!);
    final mo = int.tryParse(m[2]!);
    final d = int.tryParse(m[3]!);
    if (y == null || mo == null || d == null) return null;
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, mo, d);
    if (dt.year != y || dt.month != mo || dt.day != d) return null;
    return dt;
  }
}
