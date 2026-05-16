import 'package:flutter/material.dart';

import '../db/database.dart';
import '../theme.dart';
import 'dashboard_card.dart';
import 'status_chip.dart';

class VarietyCard extends StatelessWidget {
  final Product product;
  final String currencySymbol;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const VarietyCard({
    super.key,
    required this.product,
    this.currencySymbol = 'Rs.',
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final supports10 = product.unit.contains('p10:1') ||
        (!product.unit.contains('p10:0') && product.unit == 'qtl');
    final supports5 = product.unit.contains('p5:1') ||
        (!product.unit.contains('p5:0') && product.unit == 'qtl');

    return DashboardCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: product.isGalaxy
                      ? AppColors.secondarySurface
                      : AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  product.isGalaxy ? Icons.star : Icons.grass_outlined,
                  color: product.isGalaxy
                      ? AppColors.secondary
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.sku?.isNotEmpty == true
                          ? product.sku!
                          : 'Standard variety',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$currencySymbol${product.defaultPrice.toStringAsFixed(0)}',
                  style: AppTypography.metricMedium,
                ),
              ),
              Text(
                'per QTL',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (product.isGalaxy)
                const StatusChip(
                  label: 'GALAXY',
                  icon: Icons.star,
                  color: AppColors.secondary,
                ),
              if (product.gstRateDefault > 0)
                StatusChip(
                  label: 'GST ${product.gstRateDefault.toStringAsFixed(0)}%',
                  icon: Icons.percent,
                  color: AppColors.warning,
                ),
              StatusChip.info(
                label: [
                  '26kg',
                  if (supports10) '10kg',
                  if (supports5) '5kg',
                ].join(' / '),
                icon: Icons.inventory_2_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
