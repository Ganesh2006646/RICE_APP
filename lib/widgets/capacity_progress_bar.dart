import 'package:flutter/material.dart';

import '../theme.dart';

class CapacityProgressBar extends StatelessWidget {
  final double currentQtl;
  final double maxCapacity;
  final String label;

  const CapacityProgressBar({
    super.key,
    required this.currentQtl,
    required this.maxCapacity,
    this.label = 'Capacity',
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        maxCapacity <= 0 ? 0.0 : (currentQtl / maxCapacity).clamp(0.0, 1.0);
    final overCapacity = currentQtl > maxCapacity;
    final nearCapacity = progress >= 0.85 && !overCapacity;
    final color = overCapacity
        ? AppColors.error
        : nearCapacity
            ? AppColors.warning
            : AppColors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Text(
              '${currentQtl.toStringAsFixed(1)} / ${maxCapacity.toStringAsFixed(0)} QTL',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 10,
              color: color,
              backgroundColor: AppColors.surfaceMuted,
            ),
          ),
        ),
      ],
    );
  }
}
