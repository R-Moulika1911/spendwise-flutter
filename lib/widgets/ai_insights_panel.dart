import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import '../utils/formatters.dart';
import 'category_donut_chart.dart';

/// Visual AI insights block for the Summary screen (placed near the top).
class AiInsightsPanel extends StatelessWidget {
  const AiInsightsPanel({
    super.key,
    required this.currency,
    required this.total,
    required this.previousTotal,
    required this.slices,
    required this.monthlyBudget,
    required this.insights,
    required this.budgetAdvice,
    required this.loading,
    required this.error,
    required this.onGenerate,
  });

  final String currency;
  final double total;
  final double previousTotal;
  final List<CategorySlice> slices;
  final double? monthlyBudget;
  final AiInsightsResult? insights;
  final BudgetAdviceResult? budgetAdvice;
  final bool loading;
  final String? error;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasContent = insights != null || budgetAdvice != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI insights',
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (hasContent)
              TextButton(
                onPressed: loading ? null : onGenerate,
                child: const Text('Refresh'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MonthCompareVisual(
                currency: currency,
                total: total,
                previousTotal: previousTotal,
              ),
              if (slices.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Top categories',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                _TopCategoryBars(
                  slices: slices.take(3).toList(),
                  currency: currency,
                ),
              ],
              if (monthlyBudget != null && monthlyBudget! > 0) ...[
                const SizedBox(height: 16),
                _BudgetProgressVisual(
                  spent: total,
                  budget: monthlyBudget!,
                  currency: currency,
                  alert: budgetAdvice?.alert,
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: scheme.error, fontSize: 13),
                ),
              ],
              if (insights != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: scheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          insights!.summary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (insights!.tips.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...insights!.tips.asMap().entries.map((entry) {
                    final icons = [
                      Icons.savings_outlined,
                      Icons.trending_down_rounded,
                      Icons.checklist_rounded,
                      Icons.flag_outlined,
                    ];
                    final icon = icons[entry.key % icons.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TipCard(icon: icon, text: entry.value),
                    );
                  }),
                ],
              ],
              if (budgetAdvice != null) ...[
                const SizedBox(height: 8),
                _AdviceCard(
                  advice: budgetAdvice!.advice,
                  suggestedBudget: budgetAdvice!.suggestedBudget,
                  currency: currency,
                ),
              ],
              if (!hasContent) ...[
                const SizedBox(height: 12),
                Text(
                  'Get a short spending story, tips, and budget advice from this month’s totals.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: loading ? null : onGenerate,
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(
                      loading ? 'Generating…' : 'Generate AI insights',
                    ),
                  ),
                ),
              ] else if (loading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 3),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});
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

class _MonthCompareVisual extends StatelessWidget {
  const _MonthCompareVisual({
    required this.currency,
    required this.total,
    required this.previousTotal,
  });

  final String currency;
  final double total;
  final double previousTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxVal = [total, previousTotal, 1.0].reduce((a, b) => a > b ? a : b);
    final delta = total - previousTotal;
    final Color deltaColor;
    final IconData deltaIcon;
    final String deltaText;
    if (previousTotal == 0 && total == 0) {
      deltaColor = scheme.onSurface.withValues(alpha: 0.55);
      deltaIcon = Icons.remove_rounded;
      deltaText = 'No change';
    } else if (delta > 0) {
      deltaColor = scheme.error;
      deltaIcon = Icons.arrow_upward_rounded;
      deltaText = '${Formatters.money(delta, currency)} more';
    } else if (delta < 0) {
      deltaColor = const Color(0xFF2E7D32);
      deltaIcon = Icons.arrow_downward_rounded;
      deltaText = '${Formatters.money(-delta, currency)} less';
    } else {
      deltaColor = scheme.onSurface.withValues(alpha: 0.55);
      deltaIcon = Icons.remove_rounded;
      deltaText = 'Same as last month';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'This vs last month',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            Icon(deltaIcon, size: 16, color: deltaColor),
            const SizedBox(width: 4),
            Text(
              deltaText,
              style: theme.textTheme.labelLarge?.copyWith(
                color: deltaColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CompareBar(
          label: 'This month',
          amount: total,
          maxVal: maxVal,
          currency: currency,
          color: scheme.primary,
        ),
        const SizedBox(height: 8),
        _CompareBar(
          label: 'Last month',
          amount: previousTotal,
          maxVal: maxVal,
          currency: currency,
          color: scheme.outline.withValues(alpha: 0.55),
        ),
      ],
    );
  }
}

class _CompareBar extends StatelessWidget {
  const _CompareBar({
    required this.label,
    required this.amount,
    required this.maxVal,
    required this.currency,
    required this.color,
  });

  final String label;
  final double amount;
  final double maxVal;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = (amount / maxVal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: theme.textTheme.bodySmall),
            ),
            Text(
              Formatters.money(amount, currency),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TopCategoryBars extends StatelessWidget {
  const _TopCategoryBars({
    required this.slices,
    required this.currency,
  });

  final List<CategorySlice> slices;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: slice.category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    slice.category.icon,
                    size: 15,
                    color: slice.category.color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              slice.category.name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${slice.percent.toStringAsFixed(0)}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (slice.percent / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: slice.category.color
                              .withValues(alpha: 0.12),
                          color: slice.category.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: Text(
                    Formatters.money(slice.amount, currency),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BudgetProgressVisual extends StatelessWidget {
  const _BudgetProgressVisual({
    required this.spent,
    required this.budget,
    required this.currency,
    this.alert,
  });

  final double spent;
  final double budget;
  final String currency;
  final String? alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = (spent / budget).clamp(0.0, 1.5);
    final over = spent > budget;
    final color = over
        ? scheme.error
        : ratio >= 0.85
            ? const Color(0xFFE65100)
            : scheme.primary;
    final pct = ((spent / budget) * 100).clamp(0, 999);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                over ? Icons.warning_amber_rounded : Icons.account_balance_wallet_outlined,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  over ? 'Over budget' : 'Budget used',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: color.withValues(alpha: 0.15),
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${Formatters.money(spent, currency)} of ${Formatters.money(budget, currency)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (alert != null && alert!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              alert!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({
    required this.advice,
    required this.currency,
    this.suggestedBudget,
  });

  final String advice;
  final String currency;
  final double? suggestedBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: scheme.tertiary),
              const SizedBox(width: 8),
              Text(
                'Budget advice',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(advice, style: theme.textTheme.bodyMedium),
          if (suggestedBudget != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Suggested: ${Formatters.money(suggestedBudget!, currency)}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
