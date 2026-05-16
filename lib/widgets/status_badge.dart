import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? backgroundColor;
  final IconData? icon;
  final double fontSize;
  final bool isCompact;

  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.backgroundColor,
    this.icon,
    this.fontSize = 11,
    this.isCompact = false,
  });

  factory StatusBadge.draft() => const StatusBadge(
        label: 'Draft',
        color: AppColors.draft,
        backgroundColor: AppColors.infoLight,
      );

  factory StatusBadge.exported() => const StatusBadge(
        label: 'Exported',
        color: AppColors.exported,
        backgroundColor: AppColors.cardBlue,
      );

  factory StatusBadge.shared() => const StatusBadge(
        label: 'Shared',
        color: AppColors.shared,
        backgroundColor: AppColors.cardGreen,
      );

  factory StatusBadge.completed() => const StatusBadge(
        label: 'Completed',
        color: AppColors.completed,
        backgroundColor: AppColors.cardGreen,
      );

  factory StatusBadge.galaxy() => const StatusBadge(
        label: 'GALAXY',
        color: AppColors.warning,
        backgroundColor: AppColors.cardGold,
        isCompact: true,
      );

  factory StatusBadge.gst(double rate) => StatusBadge(
        label: rate > 0 ? 'GST ${rate.toInt()}%' : '',
        color: rate > 0 ? AppColors.warning : AppColors.textHint,
        backgroundColor:
            rate > 0 ? AppColors.warningLight : AppColors.infoLight,
        isCompact: true,
      );

  factory StatusBadge.exempted() => const StatusBadge(
        label: 'EXEMPTED',
        color: AppColors.info,
        backgroundColor: AppColors.infoLight,
        isCompact: true,
      );

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? AppColors.textSecondary;
    final bgColor = backgroundColor ?? badgeColor.withValues(alpha: 0.1);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
        border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize, color: badgeColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 10 : fontSize,
              fontWeight: FontWeight.w600,
              color: badgeColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
