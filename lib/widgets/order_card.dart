import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../theme.dart';
import 'dashboard_card.dart';
import 'status_chip.dart';

class OrderCard extends StatelessWidget {
  final OrderWithDetails orderDetails;
  final String currencySymbol;
  final VoidCallback? onTap;
  final VoidCallback? onExport;
  final VoidCallback? onEmail;
  final VoidCallback? onShare;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isProcessing;

  const OrderCard({
    super.key,
    required this.orderDetails,
    this.currencySymbol = 'Rs.',
    this.onTap,
    this.onExport,
    this.onEmail,
    this.onShare,
    this.onEdit,
    this.onDelete,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    final order = orderDetails.order;
    final qtl = orderDetails.items.fold<double>(0, (s, i) => s + i.qtyQtl);
    final parties = orderDetails.customers.length;
    final date = DateFormat('dd MMM yyyy').format(order.loadingDate);

    return DashboardCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.notes ?? 'No order number',
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$date · $parties ${parties == 1 ? 'party' : 'parties'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  '$currencySymbol${order.totalAmount.toStringAsFixed(0)}',
                  style: AppTypography.metricMedium.copyWith(
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusChip.info(
                label: '${qtl.toStringAsFixed(1)} QTL',
                icon: Icons.scale_outlined,
              ),
              StatusChip(
                label: order.paymentStatus,
                icon: Icons.account_balance_wallet_outlined,
                color: order.paymentStatus == 'PAID'
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const StatusChip.success(
                label: 'Ready',
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: onEdit,
                ),
                _ActionButton(
                  icon: Icons.download_outlined,
                  label: 'Export',
                  onTap: onExport,
                  loading: isProcessing,
                ),
                _ActionButton(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  onTap: onEmail,
                ),
                _ActionButton(
                  icon: Icons.send_outlined,
                  label: 'Share',
                  onTap: onShare,
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon:
                      const Icon(Icons.delete_outline, color: AppColors.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
