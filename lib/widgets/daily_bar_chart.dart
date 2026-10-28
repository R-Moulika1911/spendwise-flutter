import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DailyBarChart extends StatelessWidget {
  const DailyBarChart({
    super.key,
    required this.dailyTotals,
    required this.month,
  });

  final Map<int, double> dailyTotals;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final maxY = dailyTotals.values.fold<double>(0, (a, b) => a > b ? a : b);
    final chartMax = maxY <= 0 ? 100.0 : maxY * 1.25;

    if (maxY <= 0) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No daily activity yet',
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
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: chartMax,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final day = value.toInt();
                  if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
                  if (day == 1 || day == 15 || day == daysInMonth) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '$day',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          barGroups: [
            for (var day = 1; day <= daysInMonth; day++)
              BarChartGroupData(
                x: day,
                barRods: [
                  BarChartRodData(
                    toY: dailyTotals[day] ?? 0,
                    width: daysInMonth > 28 ? 4 : 6,
                    borderRadius: BorderRadius.circular(4),
                    color: AppColors.teal.withValues(alpha: 0.85),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
