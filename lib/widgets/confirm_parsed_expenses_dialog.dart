import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/parsed_expense.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../services/budget_alert_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Shows a table of AI-parsed expenses. Saves only after the user confirms.
Future<bool> showConfirmParsedExpensesDialog({
  required BuildContext context,
  required List<ParsedExpense> expenses,
  String? originalText,
}) async {
  if (expenses.isEmpty) return false;

  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ConfirmParsedExpensesDialog(
      expenses: expenses,
      originalText: originalText,
    ),
  );
  return saved == true;
}

class _ConfirmParsedExpensesDialog extends StatefulWidget {
  const _ConfirmParsedExpensesDialog({
    required this.expenses,
    this.originalText,
  });

  final List<ParsedExpense> expenses;
  final String? originalText;

  @override
  State<_ConfirmParsedExpensesDialog> createState() =>
      _ConfirmParsedExpensesDialogState();
}

class _ConfirmParsedExpensesDialogState
    extends State<_ConfirmParsedExpensesDialog> {
  late List<ParsedExpense> _rows;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rows = List<ParsedExpense>.from(widget.expenses);
  }

  String _categoryIdFor(
    ParsedExpense parsed,
    List<ExpenseCategory> categories,
  ) {
    for (final c in categories) {
      if (c.name.toLowerCase() == parsed.category.toLowerCase()) {
        return c.id;
      }
    }
    for (final c in categories) {
      if (c.id == AppConstants.otherCategoryId) {
        return c.id;
      }
    }
    return categories.isEmpty ? '' : categories.first.id;
  }

  Future<void> _editDate(int index) async {
    final current = _rows[index].date;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : current,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _rows[index] = _rows[index].copyWith(
        date: DateTime(picked.year, picked.month, picked.day),
      );
    });
  }

  Future<void> _save() async {
    final categories = context.read<CategoryProvider>().categories;
    if (categories.isEmpty) return;

    setState(() => _saving = true);
    final provider = context.read<ExpenseProvider>();
    final settings = context.read<SettingsProvider>();

    try {
      for (final parsed in _rows) {
        final categoryId = _categoryIdFor(parsed, categories);
        if (categoryId.isEmpty) continue;
        await provider.addExpense(
          amount: parsed.amount,
          categoryId: categoryId,
          date: parsed.date,
          note: parsed.note,
        );
      }
      await BudgetAlertService.checkAndNotify(
        settings: settings,
        expenses: provider,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<SettingsProvider>().currency;
    final theme = Theme.of(context);
    final count = _rows.length;
    final total = _rows.fold<double>(0, (s, e) => s + e.amount);

    return AlertDialog(
      title: Text(count == 1 ? 'Confirm expense' : 'Confirm $count expenses'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.originalText != null) ...[
                Text(
                  'From: “${widget.originalText}”',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Dates from your text are included. Tap a date to change it. Save stores everything.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  headingRowHeight: 40,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 64,
                  columns: const [
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Note')),
                  ],
                  rows: [
                    for (var i = 0; i < _rows.length; i++)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              Formatters.money(_rows[i].amount, currency),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataCell(Text(_rows[i].category)),
                          DataCell(
                            InkWell(
                              onTap: _saving ? null : () => _editDate(i),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(Formatters.dayHeader(_rows[i].date)),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.edit_calendar_outlined,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 120,
                              child: Text(
                                _rows[i].note?.isNotEmpty == true
                                    ? _rows[i].note!
                                    : '—',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (count > 1) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total: ${Formatters.money(total, currency)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(count == 1 ? 'Save' : 'Save all'),
        ),
      ],
    );
  }
}
