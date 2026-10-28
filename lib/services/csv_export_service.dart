import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/category.dart';
import '../models/expense.dart';

class CsvExportService {
  Future<File> buildCsvFile({
    required List<Expense> expenses,
    required Map<String, ExpenseCategory> categoriesById,
    required String currency,
  }) async {
    final rows = <List<dynamic>>[
      ['Date', 'Amount', 'Currency', 'Category', 'Note', 'Created At'],
    ];

    final dateFmt = DateFormat('yyyy-MM-dd');
    final sorted = [...expenses]
      ..sort((a, b) => b.date.compareTo(a.date));

    for (final e in sorted) {
      rows.add([
        dateFmt.format(e.date),
        e.amount.toStringAsFixed(2),
        currency,
        categoriesById[e.categoryId]?.name ?? e.categoryId,
        e.note ?? '',
        e.createdAt.toIso8601String(),
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/spendwise_expenses_$stamp.csv');
    await file.writeAsString(csv);
    return file;
  }

  Future<void> exportAndShare({
    required List<Expense> expenses,
    required Map<String, ExpenseCategory> categoriesById,
    required String currency,
  }) async {
    final file = await buildCsvFile(
      expenses: expenses,
      categoriesById: categoriesById,
      currency: currency,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'SpendWise expenses export',
        text: 'SpendWise expense export (${expenses.length} rows)',
      ),
    );
  }
}
