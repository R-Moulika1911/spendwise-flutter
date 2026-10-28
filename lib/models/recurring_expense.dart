enum RecurrenceFrequency { daily, weekly, monthly }

extension RecurrenceFrequencyX on RecurrenceFrequency {
  String get key => name;

  String get label => switch (this) {
        RecurrenceFrequency.daily => 'Daily',
        RecurrenceFrequency.weekly => 'Weekly',
        RecurrenceFrequency.monthly => 'Monthly',
      };

  static RecurrenceFrequency fromKey(String key) {
    return RecurrenceFrequency.values.firstWhere(
      (e) => e.name == key,
      orElse: () => RecurrenceFrequency.monthly,
    );
  }
}

class RecurringExpense {
  final String id;
  final double amount;
  final String categoryId;
  final String? note;
  final RecurrenceFrequency frequency;
  final DateTime startDate;
  final DateTime nextRun;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringExpense({
    required this.id,
    required this.amount,
    required this.categoryId,
    this.note,
    required this.frequency,
    required this.startDate,
    required this.nextRun,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  RecurringExpense copyWith({
    String? id,
    double? amount,
    String? categoryId,
    String? note,
    bool clearNote = false,
    RecurrenceFrequency? frequency,
    DateTime? startDate,
    DateTime? nextRun,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      note: clearNote ? null : (note ?? this.note),
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextRun: nextRun ?? this.nextRun,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  DateTime advance(DateTime from) {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return from.add(const Duration(days: 1));
      case RecurrenceFrequency.weekly:
        return from.add(const Duration(days: 7));
      case RecurrenceFrequency.monthly:
        return DateTime(from.year, from.month + 1, from.day);
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'categoryId': categoryId,
        'note': note,
        'frequency': frequency.key,
        'startDate': startDate.toIso8601String(),
        'nextRun': nextRun.toIso8601String(),
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'amount': amount,
        'categoryId': categoryId,
        'note': note,
        'frequency': frequency.key,
        'startDate': startDate.toIso8601String(),
        'nextRun': nextRun.toIso8601String(),
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory RecurringExpense.fromMap(Map<String, dynamic> map) {
    return RecurringExpense(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] as String,
      note: map['note'] as String?,
      frequency: RecurrenceFrequencyX.fromKey(map['frequency'] as String),
      startDate: DateTime.parse(map['startDate'] as String),
      nextRun: DateTime.parse(map['nextRun'] as String),
      isActive: map['isActive'] is bool
          ? map['isActive'] as bool
          : (map['isActive'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
