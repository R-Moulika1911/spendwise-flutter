import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../services/budget_alert_service.dart';
import '../services/category_suggest_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/category_chip.dart';
import 'categories_screen.dart';

class AddEditExpenseScreen extends StatefulWidget {
  const AddEditExpenseScreen({super.key, this.expense});

  final Expense? expense;

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  String? _categoryId;
  DateTime _date = DateTime.now();
  String? _categoryError;
  bool _saving = false;
  bool _categoryTouched = false;
  bool _suggesting = false;
  String? _suggestionHint;
  int _suggestToken = 0;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _amountController = TextEditingController(
      text: e == null ? '' : e.amount.toStringAsFixed(e.amount % 1 == 0 ? 0 : 2),
    );
    _noteController = TextEditingController(text: e?.note ?? '');
    _categoryId = e?.categoryId;
    _categoryTouched = e?.categoryId != null;
    _date = e?.date ?? DateTime.now();
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    if (_isEditing || _categoryTouched) return;
    final token = ++_suggestToken;
    Future<void>.delayed(const Duration(milliseconds: 550), () async {
      if (!mounted || token != _suggestToken || _categoryTouched) return;
      await _suggestCategory();
    });
  }

  Future<void> _suggestCategory() async {
    final note = _noteController.text.trim();
    if (note.length < 2) {
      setState(() => _suggestionHint = null);
      return;
    }
    final settings = context.read<SettingsProvider>();
    final categories = context.read<CategoryProvider>().categories;
    setState(() => _suggesting = true);
    final suggestion = await CategorySuggestService.suggest(
      note: note,
      categories: categories,
      useLlm: settings.aiConsent,
      backendBaseUrl: settings.backendBaseUrl,
    );
    if (!mounted || _categoryTouched) {
      setState(() => _suggesting = false);
      return;
    }
    if (suggestion == null) {
      setState(() {
        _suggesting = false;
        _suggestionHint = null;
      });
      return;
    }
    String? id;
    for (final c in categories) {
      if (c.name.toLowerCase() == suggestion.categoryName.toLowerCase()) {
        id = c.id;
        break;
      }
    }
    setState(() {
      _suggesting = false;
      if (id != null) {
        _categoryId = id;
        _categoryError = null;
        _suggestionHint =
            'Suggested ${suggestion.categoryName} (${suggestion.source})';
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(DateTime.now()) ? DateTime.now() : _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
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
      if (_isEditing) {
        await provider.updateExpense(
          widget.expense!.copyWith(
            amount: amount,
            categoryId: _categoryId!,
            date: _date,
            note: note.isEmpty ? null : note,
            clearNote: note.isEmpty,
          ),
        );
      } else {
        await provider.addExpense(
          amount: amount,
          categoryId: _categoryId!,
          date: _date,
          note: note.isEmpty ? null : note,
        );
      }
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
        title: Text(_isEditing ? 'Edit expense' : 'Add expense'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              'Amount',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: !_isEditing,
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
            Row(
              children: [
                Text(
                  'Category',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                    );
                  },
                  child: const Text('Manage'),
                ),
              ],
            ),
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
                      _categoryTouched = true;
                      _suggestionHint = null;
                    }),
                  ),
              ],
            ),
            if (_suggesting || _suggestionHint != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_suggesting)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (_suggesting) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _suggestionHint ?? 'Suggesting category…',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.55),
                          ),
                    ),
                  ),
                ],
              ),
            ],
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
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              leading: const Icon(Icons.calendar_today_rounded),
              title: Text(Formatters.dayHeader(_date)),
              subtitle: Text(Formatters.shortDate(_date)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),
            Text('Note (optional)', style: Theme.of(context).textTheme.labelLarge),
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
                  : Text(_isEditing ? 'Save changes' : 'Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}
