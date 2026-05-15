import 'package:flutter/material.dart';

import '../theme.dart';
import 'capacity_progress_bar.dart';
import 'dashboard_card.dart';

class CapacityProgressCard extends StatelessWidget {
  final double currentQtl;
  final double maxCapacity;
  final String? label;

  const CapacityProgressCard({
    super.key,
    required this.currentQtl,
    required this.maxCapacity,
    this.label,
  });

  bool get _isOverCapacity => (currentQtl - maxCapacity) > 0.001;
  double get _remaining => (maxCapacity - currentQtl).clamp(0, maxCapacity);

  @override
  Widget build(BuildContext context) {
    final color = _isOverCapacity ? AppColors.error : AppColors.primary;

    return DashboardCard(
      color: _isOverCapacity ? AppColors.errorLight : AppColors.surface,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _isOverCapacity
                    ? Icons.warning_amber_rounded
                    : Icons.local_shipping_outlined,
                size: 20,
                color: color,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label ?? 'Lorry Capacity',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CapacityProgressBar(
            currentQtl: currentQtl,
            maxCapacity: maxCapacity,
            label: 'Fill progress',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _isOverCapacity
                ? 'Capacity exceeded by ${(currentQtl - maxCapacity).toStringAsFixed(1)} QTL'
                : '${_remaining.toStringAsFixed(1)} QTL remaining',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
