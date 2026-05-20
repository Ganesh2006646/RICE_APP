import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme.dart';
import '../providers/analytics_provider.dart';
import '../models/daily_order_stat.dart';

class OrdersBarChart extends ConsumerWidget {
  const OrdersBarChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyOrdersAsync = ref.watch(dailyOrdersProvider);
    final mode = ref.watch(analyticsModeProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily ${mode.label}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 250,
              child: dailyOrdersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, stack) => Center(
                  child: Text(
                    'Failed to load chart data',
                    style: TextStyle(color: Colors.red.shade300),
                  ),
                ),
                data: (stats) {
                  if (stats.isEmpty) {
                    return const Center(
                      child: Text(
                        'No data available for this period',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ).animate().fadeIn();
                  }
                  
                  return _buildChart(stats, mode).animate().fadeIn().scale(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.bottomCenter,
                      );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<DailyOrderStat> stats, AnalyticsMode mode) {
    final maxY = _calculateMaxY(stats, mode);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY == 0 ? 10 : maxY * 1.2, // Add 20% top padding
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppColors.textPrimary,
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final stat = stats[group.x.toInt()];
              final date = DateFormat('MMM d').format(DateTime.parse(stat.day));
              String valText;
              
              switch (mode) {
                case AnalyticsMode.orders:
                  valText = '${stat.totalOrders} Orders';
                  break;
                case AnalyticsMode.revenue:
                  valText = NumberFormat.currency(symbol: '₹', decimalDigits: 0)
                      .format(stat.revenue);
                  break;
                case AnalyticsMode.quantity:
                  valText = '${stat.quantity.toStringAsFixed(1)} Qtl';
                  break;
              }
              
              return BarTooltipItem(
                '$date\n$valText',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= stats.length) return const SizedBox.shrink();
                
                // Show fewer labels if there are many data points
                if (stats.length > 10 && index % (stats.length ~/ 5) != 0 && index != stats.length - 1) {
                  return const SizedBox.shrink();
                }
                
                final date = DateTime.parse(stats[index].day);
                final formatted = DateFormat('d MMM').format(date);
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    formatted,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false), // Hide left axis for cleaner look
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? (maxY / 4) : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: stats.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          final value = _getValue(stat, mode);
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                color: AppColors.primary,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY == 0 ? 10 : maxY * 1.2,
                  color: AppColors.border.withValues(alpha: 0.2),
                ),
              ),
            ],
          );
        }).toList(),
      ),
      swapAnimationDuration: const Duration(milliseconds: 300),
      swapAnimationCurve: Curves.easeInOut,
    );
  }

  double _calculateMaxY(List<DailyOrderStat> stats, AnalyticsMode mode) {
    if (stats.isEmpty) return 0.0;
    return stats.map((e) => _getValue(e, mode)).reduce((a, b) => a > b ? a : b);
  }

  double _getValue(DailyOrderStat stat, AnalyticsMode mode) {
    switch (mode) {
      case AnalyticsMode.orders:
        return stat.totalOrders.toDouble();
      case AnalyticsMode.revenue:
        return stat.revenue;
      case AnalyticsMode.quantity:
        return stat.quantity;
    }
  }
}
