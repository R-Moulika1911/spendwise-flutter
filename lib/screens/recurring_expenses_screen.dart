import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/recurring_expense.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/category_chip.dart';
import '../widgets/empty_state.dart';

class RecurringExpensesScreen extends StatelessWidget {
  const RecurringExpensesScreen({super.key});

  Future<void> _openEditor(
    BuildContext context, {
    RecurringExpense? item,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RecurringEditor(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recurring = context.watch<RecurringProvider>();
    final categories = context.watch<CategoryProvider>();
    final currency = context.watch<SettingsProvider>().currency;

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Recurring expenses'),
        actions: [
          IconButton(
            tooltip: 'Process due now',
            onPressed: () async {
              final created = await recurring.processDue(
                context.read<ExpenseProvider>(),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    created == 0
                        ? 'Nothing due'
                        : 'Created $created expense${created == 1 ? '' : 's'}',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_circle_outline_rounded),
          ),
        ],
      ),
      body: recurring.items.isEmpty
          ? EmptyState(
              icon: Icons.autorenew_rounded,
              title: 'No recurring items',
              message: 'Add rent, subscriptions, or other repeating spends.',
              actionLabel: 'Add recurring',
              onAction: () => _openEditor(context),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: recurring.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = recurring.items[index];
                final cat = categories.byId(item.categoryId);
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: Theme.of(context).brightness == Brightness.light
                      ? Colors.white.withValues(alpha: 0.72)
                      : Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.35),
                  leading: CircleAvatar(
                    backgroundColor:
                        (cat?.color ?? Colors.grey).withValues(alpha: 0.15),
                    child: Icon(
                      cat?.icon ?? Icons.autorenew_rounded,
                      color: cat?.color,
                    ),
                  ),
                  title: Text(
                    '${Formatters.money(item.amount, currency)} · ${item.frequency.label}',
                  ),
                  subtitle: Text(
                    [
                      cat?.name ?? 'Category',
                      if (item.note != null && item.note!.isNotEmpty) item.note!,
                      'Next: ${Formatters.shortDate(item.nextRun)}',
                      item.isActive ? 'Active' : 'Paused',
                    ].join(' · '),
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          await _openEditor(context, item: item);
                        case 'toggle':
                          await recurring.toggleActive(item);
                        case 'delete':
                          await recurring.delete(item.id);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(item.isActive ? 'Pause' : 'Resume'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
    );
  }
}

class _RecurringEditor extends StatefulWidget {
  const _RecurringEditor({this.item});
  final RecurringExpense? item;

  @override
  State<_RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends State<_RecurringEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  String? _categoryId;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  DateTime _startDate = DateTime.now();
  String? _categoryError;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _amount = TextEditingController(
      text: item == null
          ? ''
          : item.amount.toStringAsFixed(item.amount % 1 == 0 ? 0 : 2),
    );
    _note = TextEditingController(text: item?.note ?? '');
    _categoryId = item?.categoryId;
    _frequency = item?.frequency ?? RecurrenceFrequency.monthly;
    _startDate = item?.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final catErr = Validators.category(_categoryId);
    setState(() => _categoryError = catErr);
    if (!(_formKey.currentState?.validate() ?? false) || catErr != null) return;

    final provider = context.read<RecurringProvider>();
    final amount = double.parse(_amount.text.trim());
    final note = _note.text.trim();

    if (widget.item == null) {
      await provider.add(
        amount: amount,
        categoryId: _categoryId!,
        note: note.isEmpty ? null : note,
        frequency: _frequency,
        startDate: _startDate,
      );
    } else {
      await provider.updateItem(
        widget.item!.copyWith(
          amount: amount,
          categoryId: _categoryId!,
          note: note.isEmpty ? null : note,
          clearNote: note.isEmpty,
          frequency: _frequency,
          startDate: Formatters.dateOnly(_startDate),
          nextRun: Formatters.dateOnly(_startDate),
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories;
    final currency = context.watch<SettingsProvider>().currency;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.item == null ? 'New recurring expense' : 'Edit recurring',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$currency ',
                ),
                validator: Validators.amount,
              ),
              const SizedBox(height: 12),
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
              if (_categoryError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _categoryError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurrenceFrequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: [
                  for (final f in RecurrenceFrequency.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _frequency = v);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start / next date'),
                subtitle: Text(Formatters.shortDate(_startDate)),
                trailing: const Icon(Icons.calendar_today_rounded),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
              TextFormField(
                controller: _note,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _save,
                child: Text(widget.item == null ? 'Create' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
