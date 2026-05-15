import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';

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

  double get _progress => maxCapacity > 0 ? (currentQtl / maxCapacity).clamp(0.0, 1.0) : 0.0;
  double get _remaining => (maxCapacity - currentQtl).clamp(0, maxCapacity);
  bool get _isOverCapacity => currentQtl > maxCapacity;
  bool get _isNearCapacity => _progress >= 0.85 && !_isOverCapacity;

  Color get _barColor {
    if (_isOverCapacity) return AppColors.error;
    if (_isNearCapacity) return AppColors.warning;
    return AppColors.primary;
  }

  Color get _bgColor {
    if (_isOverCapacity) return AppColors.errorLight;
    if (_isNearCapacity) return AppColors.warningLight;
    return AppColors.primarySurface;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _barColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _isOverCapacity
                    ? Icons.warning_amber_rounded
                    : Icons.local_shipping,
                size: 18,
                color: _barColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label ?? 'Lorry Capacity',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _barColor,
                ),
              ),
              const Spacer(),
              Text(
                '${currentQtl.toStringAsFixed(1)} / ${maxCapacity.toStringAsFixed(0)} QTL',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _isOverCapacity ? 1.0 : _progress,
              minHeight: 10,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(_barColor),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                _isOverCapacity
                    ? '⚠ Capacity exceeded by ${(currentQtl - maxCapacity).toStringAsFixed(1)} QTL'
                    : '${_remaining.toStringAsFixed(1)} QTL remaining',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _barColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
