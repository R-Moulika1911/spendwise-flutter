import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../services/backend_api_service.dart';
import '../utils/formatters.dart';
import '../widgets/ai_insights_panel.dart';
import '../widgets/category_donut_chart.dart';
import '../widgets/daily_bar_chart.dart';
import '../widgets/empty_state.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late DateTime _month;
  List<Expense> _monthExpenses = [];
  List<Expense> _prevExpenses = [];
  bool _loading = true;
  int? _lastExpenseCount;
  double? _lastExpenseSum;

  AiInsightsResult? _insights;
  BudgetAdviceResult? _budgetAdvice;
  bool _aiLoading = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final expenses = context.watch<ExpenseProvider>().expenses;
    final count = expenses.length;
    final sum = expenses.fold<double>(0, (s, e) => s + e.amount);
    if (_lastExpenseCount != count || _lastExpenseSum != sum) {
      _lastExpenseCount = count;
      _lastExpenseSum = sum;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _insights = null;
      _budgetAdvice = null;
      _aiError = null;
    });
    final repo = context.read<ExpenseProvider>();
    final current = await repo.expensesForMonth(_month);
    final prevMonth = DateTime(_month.year, _month.month - 1);
    final previous = await repo.expensesForMonth(prevMonth);
    if (!mounted) return;
    setState(() {
      _monthExpenses = current;
      _prevExpenses = previous;
      _loading = false;
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _load();
  }

  Future<void> _loadAiInsights({required bool includeBudget}) async {
    final settings = context.read<SettingsProvider>();
    if (!settings.aiConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable AI assistance in Settings')),
      );
      return;
    }
    final baseUrl = settings.backendBaseUrl?.trim();
    if (baseUrl == null || baseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set Backend API URL in Settings')),
      );
      return;
    }

    final categories = context.read<CategoryProvider>();
    final total = _monthExpenses.fold<double>(0, (s, e) => s + e.amount);
    final prevTotal = _prevExpenses.fold<double>(0, (s, e) => s + e.amount);
    final byCat = <String, double>{};
    for (final e in _monthExpenses) {
      final name = categories.byId(e.categoryId)?.name ?? 'Other';
      byCat[name] = (byCat[name] ?? 0) + e.amount;
    }
    final byCategory = byCat.entries
        .map(
          (e) => {
            'name': e.key,
            'amount': e.value,
            'percent': total <= 0 ? 0.0 : (e.value / total) * 100,
          },
        )
        .toList();

    final monthKey =
        '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final elapsedDays =
        Formatters.isSameMonth(_month, now) ? now.day : daysInMonth;
    final daysLeft =
        Formatters.isSameMonth(_month, now) ? (daysInMonth - now.day) : 0;
    final dailyAvg = elapsedDays == 0 ? 0.0 : total / elapsedDays;

    setState(() {
      _aiLoading = true;
      _aiError = null;
    });

    final api = BackendApiService(baseUrl: baseUrl);
    final errors = <String>[];

    try {
      try {
        final insights = await api.monthlyInsights(
          month: monthKey,
          total: total,
          previousTotal: prevTotal,
          byCategory: byCategory,
          currency: settings.currency,
        );
        if (mounted) setState(() => _insights = insights);
      } catch (e) {
        errors.add(e.toString().replaceFirst('Exception: ', ''));
      }

      if (includeBudget) {
        try {
          final advice = await api.budgetAdvice(
            monthlyBudget: settings.monthlyBudget,
            spentThisMonth: total,
            avgDaily: dailyAvg,
            daysLeft: daysLeft,
            byCategory: byCategory
                .map((e) => {'name': e['name'], 'amount': e['amount']})
                .toList(),
            currency: settings.currency,
          );
          if (mounted) setState(() => _budgetAdvice = advice);
        } catch (e) {
          errors.add(e.toString().replaceFirst('Exception: ', ''));
        }
      }
    } finally {
      if (!mounted) return;
      final hasAny = _insights != null || _budgetAdvice != null;
      // Only show a hard error when nothing useful came back.
      setState(() {
        _aiError = (!hasAny && errors.isNotEmpty) ? errors.join('\n') : null;
        _aiLoading = false;
      });
      if (hasAny && errors.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loaded available AI tips (one request was empty).'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currency;

    // Refresh when expenses change.
    context.watch<ExpenseProvider>();

    final total = _monthExpenses.fold<double>(0, (s, e) => s + e.amount);
    final prevTotal = _prevExpenses.fold<double>(0, (s, e) => s + e.amount);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final now = DateTime.now();
    final elapsedDays = Formatters.isSameMonth(_month, now)
        ? now.day
        : daysInMonth;
    final dailyAvg = elapsedDays == 0 ? 0.0 : total / elapsedDays;
    final highest = _monthExpenses.isEmpty
        ? null
        : _monthExpenses.reduce((a, b) => a.amount >= b.amount ? a : b);

    final totalsByCat = <String, double>{};
    for (final e in _monthExpenses) {
      totalsByCat[e.categoryId] = (totalsByCat[e.categoryId] ?? 0) + e.amount;
    }
    final slices = totalsByCat.entries
        .map((e) {
          final cat = categories.byId(e.key);
          if (cat == null) return null;
          return CategorySlice(
            category: cat,
            amount: e.value,
            percent: total <= 0 ? 0 : (e.value / total) * 100,
          );
        })
        .whereType<CategorySlice>()
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final daily = <int, double>{};
    for (final e in _monthExpenses) {
      daily[e.date.day] = (daily[e.date.day] ?? 0) + e.amount;
    }

    final delta = total - prevTotal;
    final deltaLabel = prevTotal == 0 && total == 0
        ? 'No change vs last month'
        : delta > 0
            ? '${Formatters.money(delta, currency)} more than last month'
            : delta < 0
                ? '${Formatters.money(-delta, currency)} less than last month'
                : 'Same as last month';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      Formatters.monthYear(_month),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: Formatters.isSameMonth(_month, DateTime.now())
                        ? null
                        : () => _shiftMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _monthExpenses.isEmpty
                      ? EmptyState(
                          icon: Icons.pie_chart_outline_rounded,
                          title: 'Nothing to summarize',
                          message:
                              'Add expenses in ${Formatters.monthYear(_month)} to see charts and breakdowns.',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                            children: [
                              _SummaryCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total spent',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.55),
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      Formatters.money(total, currency),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      deltaLabel,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatTile(
                                      label: 'Daily avg',
                                      value: Formatters.money(dailyAvg, currency),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatTile(
                                      label: 'Highest',
                                      value: highest == null
                                          ? '—'
                                          : Formatters.money(
                                              highest.amount,
                                              currency,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              AiInsightsPanel(
                                currency: currency,
                                total: total,
                                previousTotal: prevTotal,
                                slices: slices,
                                monthlyBudget: settings.monthlyBudget,
                                insights: _insights,
                                budgetAdvice: _budgetAdvice,
                                loading: _aiLoading,
                                error: _aiError,
                                onGenerate: () =>
                                    _loadAiInsights(includeBudget: true),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'By category',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              _SummaryCard(
                                child: CategoryDonutChart(
                                  slices: slices,
                                  currency: currency,
                                  total: total,
                                ),
                              ),
                              const SizedBox(height: 12),
                              for (final slice in slices)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: slice.category.color
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          slice.category.icon,
                                          size: 18,
                                          color: slice.category.color,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              slice.category.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall,
                                            ),
                                            Text(
                                              '${slice.percent.toStringAsFixed(1)}%',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.5),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        Formatters.money(slice.amount, currency),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Text(
                                'Daily spending',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              _SummaryCard(
                                child: DailyBarChart(
                                  dailyTotals: daily,
                                  month: _month,
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white.withValues(alpha: 0.78)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white.withValues(alpha: 0.78)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
