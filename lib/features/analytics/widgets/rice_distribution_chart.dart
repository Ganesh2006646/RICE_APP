import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme.dart';
import '../providers/analytics_provider.dart';
import '../models/rice_distribution.dart';

class RiceDistributionChart extends ConsumerStatefulWidget {
  const RiceDistributionChart({super.key});

  @override
  ConsumerState<RiceDistributionChart> createState() => _RiceDistributionChartState();
}

class _RiceDistributionChartState extends ConsumerState<RiceDistributionChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final distributionAsync = ref.watch(riceDistributionProvider);
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
            const Text(
              'Rice Variety Distribution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 280,
              child: distributionAsync.when(
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
                        'No distribution data available',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ).animate().fadeIn();
                  }

                  // Take top 5 and group others if necessary
                  final displayStats = _prepareData(stats);

                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildPieChart(displayStats, mode)
                            .animate()
                            .fadeIn()
                            .scale(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutCubic,
                            ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildLegend(displayStats, mode)
                            .animate()
                            .fadeIn(delay: const Duration(milliseconds: 200)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<RiceDistribution> _prepareData(List<RiceDistribution> stats) {
    if (stats.length <= 5) return stats;
    
    final top4 = stats.take(4).toList();
    final others = stats.skip(4);
    
    double othersQty = 0;
    double othersRev = 0;
    for (final s in others) {
      othersQty += s.quantity;
      othersRev += s.revenue;
    }
    
    top4.add(RiceDistribution(
      varietyName: 'Others',
      quantity: othersQty,
      revenue: othersRev,
    ));
    
    return top4;
  }

  Widget _buildPieChart(List<RiceDistribution> stats, AnalyticsMode mode) {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  pieTouchResponse == null ||
                  pieTouchResponse.touchedSection == null) {
                _touchedIndex = -1;
                return;
              }
              _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: stats.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          final isTouched = index == _touchedIndex;
          
          final radius = isTouched ? 60.0 : 50.0;
          final fontSize = isTouched ? 16.0 : 0.0; // Hide text when not touched to avoid clutter
          
          final value = _getValue(stat, mode);
          final color = _getColor(index);
          
          return PieChartSectionData(
            color: color,
            value: value,
            title: isTouched ? '${_getPercentage(stats, value, mode)}%' : '',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
      swapAnimationDuration: const Duration(milliseconds: 300),
      swapAnimationCurve: Curves.easeInOut,
    );
  }

  Widget _buildLegend(List<RiceDistribution> stats, AnalyticsMode mode) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final stat = stats[index];
        final val = _getValue(stat, mode);
        final color = _getColor(index);
        
        String valText;
        if (mode == AnalyticsMode.revenue) {
          valText = NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 0).format(val);
        } else {
          valText = '${val.toStringAsFixed(1)} Qtl';
        }
        
        return Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.varietyName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    valText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  double _getValue(RiceDistribution stat, AnalyticsMode mode) {
    if (mode == AnalyticsMode.revenue) {
      return stat.revenue;
    }
    // For both Orders and Quantity mode, use quantity
    return stat.quantity;
  }

  String _getPercentage(List<RiceDistribution> stats, double value, AnalyticsMode mode) {
    final total = stats.fold(0.0, (sum, item) => sum + _getValue(item, mode));
    if (total == 0) return '0';
    return ((value / total) * 100).toStringAsFixed(1);
  }

  Color _getColor(int index) {
    const colors = [
      AppColors.primary,
      Color(0xFFE57373), // Red
      Color(0xFF81C784), // Green
      Color(0xFF64B5F6), // Blue
      Color(0xFFFFB74D), // Orange
      Color(0xFF9575CD), // Purple
    ];
    return colors[index % colors.length];
  }
}
