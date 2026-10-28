import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class MonthBanner extends StatelessWidget {
  const MonthBanner({
    super.key,
    required this.month,
    required this.total,
    required this.currency,
    this.monthlyBudget,
    this.subtitle = 'This month',
  });

  final DateTime month;
  final double total;
  final String currency;
  final double? monthlyBudget;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final budget = monthlyBudget;
    final overBudget = budget != null && budget > 0 && total > budget;
    final progress = budget == null || budget <= 0
        ? null
        : (total / budget).clamp(0.0, 1.5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: overBudget
              ? const [Color(0xFF7F1D1D), Color(0xFFB91C1C), AppColors.coral]
              : const [AppColors.tealDark, AppColors.teal, Color(0xFF14B8A6)],
        ),
        boxShadow: [
          BoxShadow(
            color: (overBudget ? AppColors.coral : AppColors.teal)
                .withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  letterSpacing: 0.4,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.monthYear(month),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
          ),
          const SizedBox(height: 14),
          Text(
            Formatters.money(total, currency),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
          ),
          if (budget != null && budget > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress! > 1 ? 1 : progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              overBudget
                  ? 'Over budget by ${Formatters.money(total - budget, currency)}'
                  : '${Formatters.money(budget - total, currency)} left of ${Formatters.money(budget, currency)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
