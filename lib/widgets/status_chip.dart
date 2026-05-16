import 'package:flutter/material.dart';

import '../theme.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;

  const StatusChip({
    super.key,
    required this.label,
    this.icon,
    this.color = AppColors.primary,
  });

  const StatusChip.success({super.key, required this.label, this.icon})
      : color = AppColors.success;

  const StatusChip.warning({super.key, required this.label, this.icon})
      : color = AppColors.warning;

  const StatusChip.error({super.key, required this.label, this.icon})
      : color = AppColors.error;

  const StatusChip.info({super.key, required this.label, this.icon})
      : color = AppColors.info;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
