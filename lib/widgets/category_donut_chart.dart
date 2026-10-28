import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/category.dart';
import '../utils/formatters.dart';

class CategorySlice {
  final ExpenseCategory category;
  final double amount;
  final double percent;

  const CategorySlice({
    required this.category,
    required this.amount,
    required this.percent,
  });
}

class CategoryDonutChart extends StatelessWidget {
  const CategoryDonutChart({
    super.key,
    required this.slices,
    required this.currency,
    required this.total,
  });

  final List<CategorySlice> slices;
  final String currency;
  final double total;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty || total <= 0) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'No spending this month',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 58,
              startDegreeOffset: -90,
              sections: [
                for (final slice in slices)
                  PieChartSectionData(
                    color: slice.category.color,
                    value: slice.amount,
                    title: '',
                    radius: 42,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
              ),
              Text(
                Formatters.moneyCompact(total, currency),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
