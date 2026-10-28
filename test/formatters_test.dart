import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/utils/formatters.dart';

void main() {
  test('dayHeader groups today and yesterday', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    expect(Formatters.dayHeader(today), 'Today');
    expect(Formatters.dayHeader(yesterday), 'Yesterday');
  });

  test('money formats with currency', () {
    expect(Formatters.money(12.5, '₹'), '₹12.50');
    expect(Formatters.money(1000, '\$'), '\$1,000.00');
  });

  test('isSameMonth compares year and month', () {
    expect(
      Formatters.isSameMonth(DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
      isTrue,
    );
    expect(
      Formatters.isSameMonth(DateTime(2026, 10, 1), DateTime(2026, 11, 1)),
      isFalse,
    );
  });
}
