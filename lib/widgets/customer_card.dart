import 'package:flutter/material.dart';

import '../db/database.dart';
import '../theme.dart';
import 'dashboard_card.dart';
import 'status_chip.dart';

class CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onNewOrder;
  final VoidCallback? onDelete;

  const CustomerCard({
    super.key,
    required this.customer,
    this.onTap,
    this.onEdit,
    this.onCall,
    this.onWhatsApp,
    this.onNewOrder,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final place = customer.place?.trim();
    final gst = customer.tinGst?.trim();
    final phone = customer.phone?.trim();

    return DashboardCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.primarySurface,
                foregroundColor: AppColors.primary,
                child: Text(
                  customer.shopName.isEmpty
                      ? '?'
                      : customer.shopName.characters.first.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.shopName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (customer.ownerName?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        customer.ownerName!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (place != null && place.isNotEmpty)
                StatusChip.info(
                  label: place,
                  icon: Icons.location_on_outlined,
                ),
              if (gst != null && gst.isNotEmpty)
                StatusChip(
                  label: gst,
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.primary,
                ),
              if (phone != null && phone.isNotEmpty)
                StatusChip(
                  label: phone,
                  icon: Icons.phone_outlined,
                  color: AppColors.info,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
