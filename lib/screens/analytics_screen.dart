import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/analytics/providers/analytics_provider.dart';
import '../features/analytics/widgets/orders_bar_chart.dart';
import '../features/analytics/widgets/rice_distribution_chart.dart';
import '../theme.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(analyticsTimeFilterProvider);
    final selectedMode = ref.watch(analyticsModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Analytics'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: AppColors.background,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTimeFilters(context, ref, selectedFilter),
                    const SizedBox(height: AppSpacing.md),
                    _buildModeFilters(context, ref, selectedMode),
                    const SizedBox(height: AppSpacing.xl),
                    const OrdersBarChart(),
                    const SizedBox(height: AppSpacing.lg),
                    const RiceDistributionChart(),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilters(BuildContext context, WidgetRef ref, AnalyticsTimeFilter current) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AnalyticsTimeFilter.values.map((filter) {
          final isSelected = filter == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(filter.label),
              selected: isSelected,
              onSelected: (_) {
                ref.read(analyticsTimeFilterProvider.notifier).state = filter;
              },
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModeFilters(BuildContext context, WidgetRef ref, AnalyticsMode current) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: AnalyticsMode.values.map((mode) {
          final isSelected = mode == current;
          return Expanded(
            child: InkWell(
              onTap: () {
                ref.read(analyticsModeProvider.notifier).state = mode;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
