import 'package:flutter/material.dart';

import '../theme.dart';

class AppDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;
  final Color color;

  const AppDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(message),
      actions: actions,
    );
  }
}
