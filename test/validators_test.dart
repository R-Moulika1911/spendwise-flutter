import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/utils/validators.dart';

void main() {
  group('Validators.amount', () {
    test('rejects empty', () {
      expect(Validators.amount(null), isNotNull);
      expect(Validators.amount(''), isNotNull);
      expect(Validators.amount('  '), isNotNull);
    });

    test('rejects zero and negative', () {
      expect(Validators.amount('0'), isNotNull);
      expect(Validators.amount('-5'), isNotNull);
    });

    test('rejects more than 2 decimals', () {
      expect(Validators.amount('12.345'), isNotNull);
    });

    test('accepts valid amounts', () {
      expect(Validators.amount('10'), isNull);
      expect(Validators.amount('10.5'), isNull);
      expect(Validators.amount('10.50'), isNull);
    });
  });

  group('Validators.categoryName', () {
    test('enforces uniqueness and length', () {
      expect(Validators.categoryName(''), isNotNull);
      expect(Validators.categoryName('a' * 21), isNotNull);
      expect(
        Validators.categoryName('Food', existingNames: ['Food']),
        isNotNull,
      );
      expect(
        Validators.categoryName('Snacks', existingNames: ['Food']),
        isNull,
      );
    });
  });

  group('summary helpers', () {
    test('monthlyTotal sums amounts', () {
      expect(Validators.monthlyTotal([10, 20.5, 5]), 35.5);
      expect(Validators.monthlyTotal([]), 0);
    });

    test('groupByCategory aggregates', () {
      final grouped = Validators.groupByCategory([
        (categoryId: 'food', amount: 10),
        (categoryId: 'food', amount: 5),
        (categoryId: 'travel', amount: 20),
      ]);
      expect(grouped['food'], 15);
      expect(grouped['travel'], 20);
    });

    test('categoryPercentages computes share', () {
      final percents = Validators.categoryPercentages({
        'food': 25,
        'travel': 75,
      });
      expect(percents['food'], 25);
      expect(percents['travel'], 75);
    });
  });

  group('Validators.date', () {
    test('blocks future dates', () {
      final tomorrow = DateTime.now().add(const Duration(days: 2));
      expect(Validators.date(tomorrow), isNotNull);
      expect(Validators.date(DateTime.now()), isNull);
    });
  });
}
