import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/parsed_expense.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../services/budget_alert_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/category_chip.dart';

/// Review / edit AI-parsed fields before saving to SQLite.
class ConfirmParsedExpenseScreen extends StatefulWidget {
  const ConfirmParsedExpenseScreen({
    super.key,
    required this.parsed,
    this.originalText,
  });

  final ParsedExpense parsed;
  final String? originalText;

  @override
  State<ConfirmParsedExpenseScreen> createState() =>
      _ConfirmParsedExpenseScreenState();
}

class _ConfirmParsedExpenseScreenState
    extends State<ConfirmParsedExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  String? _categoryId;
  late DateTime _date;
  String? _categoryError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.parsed;
    _amountController = TextEditingController(
      text: p.amount.toStringAsFixed(p.amount % 1 == 0 ? 0 : 2),
    );
    _noteController = TextEditingController(text: p.note ?? '');
    _date = p.date;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cats = context.read<CategoryProvider>().categories;
      String? id;
      for (final c in cats) {
        if (c.name.toLowerCase() == p.category.toLowerCase()) {
          id = c.id;
          break;
        }
      }
      if (id == null) {
        for (final c in cats) {
          if (c.id == AppConstants.otherCategoryId) {
            id = c.id;
            break;
          }
        }
      }
      id ??= cats.isEmpty ? null : cats.first.id;
      setState(() => _categoryId = id);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(DateTime.now()) ? DateTime.now() : _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final categoryError = Validators.category(_categoryId);
    setState(() => _categoryError = categoryError);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || categoryError != null) return;

    setState(() => _saving = true);
    final amount = double.parse(_amountController.text.trim());
    final note = _noteController.text.trim();
    final provider = context.read<ExpenseProvider>();
    final settings = context.read<SettingsProvider>();

    try {
      await provider.addExpense(
        amount: amount,
        categoryId: _categoryId!,
        date: _date,
        note: note.isEmpty ? null : note,
      );
      await BudgetAlertService.checkAndNotify(
        settings: settings,
        expenses: provider,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories;
    final currency = context.watch<SettingsProvider>().currency;

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Confirm expense'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            if (widget.originalText != null) ...[
              Text(
                'From: “${widget.originalText}”',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check the details — AI can misread amounts or categories.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 20),
            ],
            Text('Amount', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                prefixText: '$currency ',
                hintText: '0.00',
              ),
              validator: Validators.amount,
            ),
            const SizedBox(height: 24),
            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in categories)
                  CategoryChip(
                    category: cat,
                    selected: _categoryId == cat.id,
                    onTap: () => setState(() {
                      _categoryId = cat.id;
                      _categoryError = null;
                    }),
                  ),
              ],
            ),
            if (_categoryError != null) ...[
              const SizedBox(height: 8),
              Text(
                _categoryError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text('Date', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                ),
              ),
              leading: const Icon(Icons.calendar_today_rounded),
              title: Text(Formatters.dayHeader(_date)),
              subtitle: Text(Formatters.shortDate(_date)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),
            Text(
              'Note (optional)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              maxLength: AppConstants.noteMaxLength,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Coffee with team, groceries…',
              ),
              validator: Validators.note,
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}
