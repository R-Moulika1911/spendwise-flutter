import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/expense_repository.dart';
import '../models/expense.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/settings_provider.dart';
import '../services/budget_alert_service.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/expense_tile.dart';
import '../widgets/month_banner.dart';
import 'add_edit_expense_screen.dart';
import 'quick_add_ai_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  double _monthTotal = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final recurring = context.read<RecurringProvider>();
    final expenses = context.read<ExpenseProvider>();
    final settings = context.read<SettingsProvider>();

    final created = await recurring.processDue(expenses);
    final now = DateTime.now();
    final total = await expenses.monthTotalUnfiltered(now);
    if (!mounted) return;
    setState(() => _monthTotal = total);

    if (created > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added $created recurring expense${created == 1 ? '' : 's'}',
          ),
        ),
      );
    }

    final notified = await BudgetAlertService.checkAndNotify(
      settings: settings,
      expenses: expenses,
    );
    if (notified && mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Budget exceeded'),
          content: Text(
            'You have spent ${Formatters.money(total, settings.currency)} '
            'this month against a budget of '
            '${Formatters.money(settings.monthlyBudget!, settings.currency)}.\n\n'
            'A notification was also sent to your device.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _refreshMonthTotal() async {
    final total = await context
        .read<ExpenseProvider>()
        .monthTotalUnfiltered(DateTime.now());
    if (mounted) setState(() => _monthTotal = total);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAdd([Expense? expense]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditExpenseScreen(expense: expense),
      ),
    );
    await _refreshMonthTotal();
  }

  Future<void> _openQuickAddAi() async {
    final settings = context.read<SettingsProvider>();
    if (!settings.aiConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable AI assistance in Settings to use Quick add'),
        ),
      );
      return;
    }
    if ((settings.backendBaseUrl ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set Backend API URL in Settings first'),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QuickAddAiScreen()),
    );
    await _refreshMonthTotal();
  }

  Future<void> _showAddOptions() async {
    final settings = context.read<SettingsProvider>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Add manually'),
              onTap: () => Navigator.pop(ctx, 'manual'),
            ),
            ListTile(
              leading: Icon(
                Icons.auto_awesome_rounded,
                color: settings.aiConsent
                    ? Theme.of(ctx).colorScheme.primary
                    : Theme.of(ctx).disabledColor,
              ),
              title: const Text('Type in natural language'),
              subtitle: Text(
                settings.aiConsent
                    ? 'e.g. “Yesterday lunch 250”'
                    : 'Turn on AI in Settings',
              ),
              onTap: () => Navigator.pop(ctx, 'ai'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'manual') await _openAdd();
    if (choice == 'ai') await _openQuickAddAi();
  }

  Future<void> _confirmDelete(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          'Remove ${Formatters.money(expense.amount, context.read<SettingsProvider>().currency)} from your list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<ExpenseProvider>();
    await provider.deleteExpense(expense.id);
    await _refreshMonthTotal();
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Expense deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await provider.undoDelete();
            await _refreshMonthTotal();
          },
        ),
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    final expenseProvider = context.read<ExpenseProvider>();
    final categories = context.read<CategoryProvider>().categories;
    var filter = expenseProvider.filter;
    DateTimeRange? range;
    if (filter.startDate != null && filter.endDate != null) {
      range = DateTimeRange(start: filter.startDate!, end: filter.endDate!);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Filter & sort',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text('Category', style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: filter.categoryId == null,
                        onSelected: (_) => setModal(() {
                          filter = filter.copyWith(clearCategory: true);
                        }),
                      ),
                      for (final cat in categories)
                        FilterChip(
                          label: Text(cat.name),
                          selected: filter.categoryId == cat.id,
                          onSelected: (_) => setModal(() {
                            filter = filter.copyWith(categoryId: cat.id);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date range'),
                    subtitle: Text(
                      range == null
                          ? 'Any dates'
                          : '${Formatters.shortDate(range!.start)} – ${Formatters.shortDate(range!.end)}',
                    ),
                    trailing: const Icon(Icons.date_range_rounded),
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: ctx,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: range,
                      );
                      if (picked != null) {
                        setModal(() {
                          range = picked;
                          filter = filter.copyWith(
                            startDate: picked.start,
                            endDate: picked.end,
                          );
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Sort by', style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<ExpenseSort>(
                    segments: const [
                      ButtonSegment(
                        value: ExpenseSort.dateDesc,
                        label: Text('Newest'),
                      ),
                      ButtonSegment(
                        value: ExpenseSort.amountDesc,
                        label: Text('Amount'),
                      ),
                      ButtonSegment(
                        value: ExpenseSort.amountAsc,
                        label: Text('Low→High'),
                      ),
                    ],
                    selected: {filter.sort},
                    onSelectionChanged: (s) => setModal(() {
                      filter = filter.copyWith(sort: s.first);
                    }),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            _searchController.clear();
                            await expenseProvider.clearFilters();
                          },
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await expenseProvider.setFilter(filter);
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>();
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currency;
    final now = DateTime.now();
    final grouped = expenses.groupedByDate;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Expenses',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search',
                    onPressed: () => setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) {
                        _searchController.clear();
                        expenses.setFilter(
                          expenses.filter.copyWith(clearSearch: true),
                        );
                      }
                    }),
                    icon: Icon(
                      _showSearch ? Icons.close_rounded : Icons.search_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Filter',
                    onPressed: _showFilterSheet,
                    icon: Badge(
                      isLabelVisible: expenses.filter.hasActiveFilters,
                      child: const Icon(Icons.tune_rounded),
                    ),
                  ),
                ],
              ),
            ),
            if (_showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search notes…',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) {
                    expenses.setFilter(
                      expenses.filter.copyWith(
                        searchQuery: value,
                        clearSearch: value.trim().isEmpty,
                      ),
                    );
                  },
                ),
              ),
            Expanded(
              child: expenses.isLoading && expenses.expenses.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async {
                        await expenses.load();
                        await categories.load();
                        await _refreshMonthTotal();
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: MonthBanner(
                                month: now,
                                total: _monthTotal,
                                currency: currency,
                                monthlyBudget: settings.monthlyBudget,
                              ),
                            ),
                          ),
                          if (expenses.expenses.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: EmptyState(
                                icon: Icons.receipt_long_rounded,
                                title: 'No expenses yet',
                                message:
                                    'Tap + to log your first spend — it takes under 10 seconds.',
                                actionLabel: 'Add expense',
                                onAction: _showAddOptions,
                              ),
                            )
                          else
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final entry = grouped.entries.elementAt(index);
                                  final date = entry.key;
                                  final items = entry.value;
                                  final dayTotal = items.fold<double>(
                                    0,
                                    (s, e) => s + e.amount,
                                  );

                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              Formatters.dayHeader(date),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              Formatters.money(dayTotal, currency),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.5),
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        for (final expense in items)
                                          ExpenseTile(
                                            expense: expense,
                                            category: categories.byId(expense.categoryId),
                                            currency: currency,
                                            onTap: () => _openAdd(expense),
                                            onDelete: () => _confirmDelete(expense),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                                childCount: grouped.length,
                              ),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 100)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
    );
  }
}
