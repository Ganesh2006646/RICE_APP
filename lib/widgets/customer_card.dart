import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/database.dart';
import '../theme.dart';
import '../services/translation_service.dart';
import '../widgets/safe_widgets.dart';
import 'dashboard_card.dart';
import 'status_chip.dart';

void _launchPhone(BuildContext context, String phone) async {
  final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'\D'), '')}');
  // ignore: unnecessary_non_null_assertion
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

/// Data model for a single purchase history entry
class PurchaseRecord {
  final String orderNo;
  final DateTime date;
  final String variety;
  final double qtyQtl;
  final int bags26;
  final int bags10;
  final int bags5;

  const PurchaseRecord({
    required this.orderNo,
    required this.date,
    required this.variety,
    required this.qtyQtl,
    this.bags26 = 0,
    this.bags10 = 0,
    this.bags5 = 0,
  });
}

class CustomerCard extends ConsumerWidget {
  final Customer customer;
  final double totalQtl;
  final List<PurchaseRecord> purchaseHistory;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CustomerCard({
    super.key,
    required this.customer,
    this.totalQtl = 0.0,
    this.purchaseHistory = const [],
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              // ── QTL Purchase Summary Badge ──
              if (totalQtl > 0)
                _PurchaseBadge(
                  totalQtl: totalQtl,
                  onTap: () => _showPurchaseHistory(context, ref),
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
                GestureDetector(
                  onTap: () => _launchPhone(context, phone),
                  child: StatusChip(
                    label: phone,
                    icon: Icons.phone_outlined,
                    color: AppColors.info,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPurchaseHistory(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd MMM yyyy');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // ── Handle ──
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.analytics_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SafeText(
                                'purchase_history'.tr(ref),
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                customer.shopName,
                                style: Theme.of(ctx)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Total badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryLight,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                totalQtl.toStringAsFixed(
                                    totalQtl == totalQtl.roundToDouble()
                                        ? 0
                                        : 1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'qty_qtl'.tr(ref),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // ── Summary Stats ──
                  if (purchaseHistory.isNotEmpty)
                    _buildSummaryStats(ctx, ref),
                  if (purchaseHistory.isNotEmpty) const Divider(height: 1),
                  // ── Column Headers ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    color: AppColors.surfaceVariant,
                    child: Row(
                      children: [
                        _colHeader(ctx, 'date'.tr(ref), flex: 3),
                        _colHeader(ctx, 'order_no'.tr(ref), flex: 2),
                        _colHeader(ctx, 'variety'.tr(ref), flex: 3),
                        _colHeader(ctx, 'qty_qtl'.tr(ref),
                            flex: 2, align: TextAlign.right),
                      ],
                    ),
                  ),
                  // ── Body ──
                  Expanded(
                    child: purchaseHistory.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory_2_outlined,
                                    size: 48,
                                    color: AppColors.textTertiary
                                        .withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                SafeText(
                                  'no_purchases'.tr(ref),
                                  style: const TextStyle(
                                      color: AppColors.textTertiary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: purchaseHistory.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: AppColors.borderLight,
                              indent: 20,
                              endIndent: 20,
                            ),
                            itemBuilder: (_, idx) {
                              final record = purchaseHistory[idx];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                child: Row(
                                  children: [
                                    // Date
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        dateFormat.format(record.date),
                                        style: Theme.of(ctx)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                    // Order No
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        record.orderNo,
                                        style: Theme.of(ctx)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    // Variety
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        record.variety,
                                        style: Theme.of(ctx)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // QTL
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        record.qtyQtl.toStringAsFixed(
                                            record.qtyQtl ==
                                                    record.qtyQtl
                                                        .roundToDouble()
                                                ? 0
                                                : 2),
                                        textAlign: TextAlign.right,
                                        style: Theme.of(ctx)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryDark,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryStats(BuildContext ctx, WidgetRef ref) {
    final distinctOrders = purchaseHistory.map((r) => r.orderNo).toSet().length;
    final firstDate = purchaseHistory.map((r) => r.date).reduce(
        (a, b) => a.isBefore(b) ? a : b);
    final lastDate = purchaseHistory.map((r) => r.date).reduce(
        (a, b) => a.isAfter(b) ? a : b);
    final dateFormat = DateFormat('dd MMM yy');

    // Top variety by QTL
    final varietyQtl = <String, double>{};
    for (final r in purchaseHistory) {
      varietyQtl[r.variety] = (varietyQtl[r.variety] ?? 0) + r.qtyQtl;
    }
    final topVariety = varietyQtl.entries.reduce(
        (a, b) => a.value >= b.value ? a : b);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.primarySurface.withValues(alpha: 0.4),
      child: Column(
        children: [
          Row(
            children: [
              _statTile(ctx, Icons.receipt_long, 'Orders',
                  distinctOrders.toString(), AppColors.primary),
              const SizedBox(width: 8),
              _statTile(ctx, Icons.calendar_today, 'First',
                  dateFormat.format(firstDate), AppColors.info),
              const SizedBox(width: 8),
              _statTile(ctx, Icons.event, 'Last',
                  dateFormat.format(lastDate), const Color(0xFF7C3AED)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Top: ${topVariety.key}',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${topVariety.value.toStringAsFixed(topVariety.value == topVariety.value.roundToDouble() ? 0 : 1)} QTL',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(BuildContext ctx, IconData icon, String label,
      String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 12,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _colHeader(BuildContext ctx, String label,
      {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

/// Compact purchase summary badge — shows total QTL
class _PurchaseBadge extends StatelessWidget {
  final double totalQtl;
  final VoidCallback onTap;

  const _PurchaseBadge({required this.totalQtl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F5D45), Color(0xFF2F7D62)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              totalQtl.toStringAsFixed(
                  totalQtl == totalQtl.roundToDouble() ? 0 : 1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const Text(
              'QTL',
              style: TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
