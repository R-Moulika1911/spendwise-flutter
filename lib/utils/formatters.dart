import 'package:intl/intl.dart';

class Formatters {
  static String money(double amount, String currency) {
    final formatted = NumberFormat('#,##0.00').format(amount);
    return '$currency$formatted';
  }

  static String moneyCompact(double amount, String currency) {
    if (amount >= 100000) {
      return '$currency${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '$currency${(amount / 1000).toStringAsFixed(1)}k';
    }
    return money(amount, currency);
  }

  static String dayHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, d MMM yyyy').format(date);
  }

  static String monthYear(DateTime date) => DateFormat('MMMM yyyy').format(date);

  static String shortDate(DateTime date) => DateFormat('d MMM').format(date);

  static String dayLabel(DateTime date) => DateFormat('d').format(date);

  static String weekdayShort(DateTime date) => DateFormat('E').format(date);

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;
}
