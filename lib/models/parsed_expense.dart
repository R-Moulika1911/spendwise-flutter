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

  factory ParsedExpense.fromJson(Map<String, dynamic> json) {
    final dateRaw = json['date'] as String? ?? '';
    final parsedDate = DateTime.tryParse(dateRaw);
    final date = parsedDate == null
        ? DateTime.now()
        : DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

    return ParsedExpense(
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String? ?? 'Other',
      date: date,
      note: json['note'] as String?,
    );
  }
}
