import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../main.dart';
import '../theme.dart';
import '../db/database.dart';
import '../services/excel_service.dart';
import '../services/email_service.dart';
import '../services/whatsapp_service.dart';
import '../services/pdf_service.dart';
import '../widgets/safe_widgets.dart';
import 'new_order_screen.dart';
import '../services/translation_service.dart';
import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/order_card.dart';
import '../utils/page_transitions.dart';

/// Orders History Screen with filters and actions
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _searchQuery = '';
  final _dateFormat = DateFormat('dd MMM yyyy');
  final _searchController = TextEditingController();
  bool _isProcessing = false;
  String? _processingOrderId;
  Stream<List<OrderWithDetails>>? _ordersStream;

  @override
  void dispose() {
    _searchController.dispose();
    _searchQuery = ''; // reset on dispose to avoid stale state
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: SafeText('order_history'.tr(ref),
            style: const TextStyle(fontSize: 18)),
      ),
      body: SafePage(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            StreamBuilder<List<OrderWithDetails>>(
              stream: _ordersStream ??= _buildOrdersQuery(db),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var orders = snapshot.data!;
                
                // ── Client-side filtering ──
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery; // already normalised
                  orders = orders.where((item) {
                    String norm(String? s) => (s ?? '')
                        .trim()
                        .toLowerCase()
                        .replaceAll(RegExp(r'\s+'), ' ');
                    final orderNo = norm(item.order.notes);
                    final customers = item.customers
                        .map((c) => norm(c.shopName))
                        .join(' ');
                    return orderNo.contains(q) || customers.contains(q);
                  }).toList();
                }

                if (orders.isEmpty && _searchQuery.isEmpty) {
                  return _buildEmptyState();
                }

                return Column(
                  children: [
                    // SEARCH BAR
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'search_orders_hint'.tr(ref),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _searchController.clear();
                                    });
                                  })
                              : null,
                          filled: true,
                          fillColor: theme.cardColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (val) {
                          // Normalise: trim + lowercase + collapse spaces
                          setState(() => _searchQuery = val
                              .trim()
                              .toLowerCase()
                              .replaceAll(RegExp(r'\s+'), ' '));
                        },
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), // Prevent FAB overlap
                      itemCount: orders.length,
                      itemBuilder: (context, index) =>
                          _buildOrderCard(orders[index], db),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Stream<List<OrderWithDetails>> _buildOrdersQuery(AppDatabase db) {
    final ordersStream = (db.select(db.orders)
          ..orderBy([
            (t) => drift.OrderingTerm(
                expression: t.createdAt, mode: drift.OrderingMode.desc)
          ]))
        .watch();
    return ordersStream.asyncMap((orders) async {
      if (orders.isEmpty) return [];
      final orderIds = orders.map((o) => o.id).toList();
      final shipmentRows = await (db.select(db.lorryShipments).join([
        drift.innerJoin(db.customers,
            db.customers.id.equalsExp(db.lorryShipments.customerId))
      ])
            ..where(db.lorryShipments.orderId.isIn(orderIds)))
          .get();

      final orderCustomers = <String, List<Customer>>{};
      for (var row in shipmentRows) {
        final oId = row.readTable(db.lorryShipments).orderId;
        orderCustomers
            .putIfAbsent(oId, () => [])
            .add(row.readTable(db.customers));
      }

      // Load order items for QTL display
      final allItems = await (db.select(db.orderItems)
            ..where((tbl) => tbl.orderId.isIn(orderIds)))
          .get();
      final orderItems = <String, List<OrderItem>>{};
      for (var oi in allItems) {
        orderItems.putIfAbsent(oi.orderId, () => []).add(oi);
      }

      final results = orders
          .map((order) => OrderWithDetails(
              order: order,
              customers: orderCustomers[order.id] ?? [],
              items: orderItems[order.id] ?? []))
          .toList();
      return results;
    });
  }

  Widget _buildOrderCard(OrderWithDetails item, AppDatabase db) {
    return OrderCard(
      orderDetails: item,
      currencySymbol: ref.watch(settingsProvider).currencySymbol,
      onTap: () => _showOrderDetails(item, db),
      onEdit: _isProcessing ? null : () => _duplicateOrder(item),
      onExport: _isProcessing ? null : () => _downloadExcel(item, db),
      onEmail: _isProcessing ? null : () => _resendEmail(item, db),
      onShare: _isProcessing ? null : () => _sendWhatsApp(item, db),
      onDelete: _isProcessing ? null : () => _confirmDeleteOrder(item, db),
      isProcessing: _processingOrderId == '${item.order.id}_excel',
    );
  }

  Future<void> _confirmDeleteOrder(
      OrderWithDetails item, AppDatabase db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('${'delete'.tr(ref)}?'),
        content: Text('delete_order_confirm'.tr(ref)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr(ref))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('delete'.tr(ref)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await db.transaction(() async {
          // 1. Delete order items
          await (db.delete(db.orderItems)
                ..where((tbl) => tbl.orderId.equals(item.order.id)))
              .go();
          // 2. Delete lorry shipments
          await (db.delete(db.lorryShipments)
                ..where((tbl) => tbl.orderId.equals(item.order.id)))
              .go();
          // 3. Delete payment records (fixes orphaned payments bug)
          await (db.delete(db.payments)
                ..where((tbl) => tbl.orderId.equals(item.order.id)))
              .go();
          // 4. Delete the order itself
          await (db.delete(db.orders)
                ..where((tbl) => tbl.id.equals(item.order.id)))
              .go();
        });
        _showSuccess('deleted_success'.tr(ref));
      } catch (e) {
        _showError('${'failed_to_delete'.tr(ref)}: $e');
      }
    }
  }

  Future<void> _showOrderDetails(OrderWithDetails item, AppDatabase db) async {
    final orderItems = await (db.select(db.orderItems)
          ..where((tbl) => tbl.orderId.equals(item.order.id)))
        .get();
    final products = await db.select(db.products).get();
    if (!mounted) return;
    final theme = Theme.of(context);
    final currency = ref.read(settingsProvider).currencySymbol;

    // Group items by customer
    final groupedItems = <String, List<OrderItem>>{};
    for (var oi in orderItems) {
      groupedItems.putIfAbsent(oi.customerId, () => []).add(oi);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Fully transparent for custom look
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header
                    SafeRow(
                      leading: SafeColumn(
                        children: [
                          SafeText(
                              '${'order_no'.tr(ref)}: ${item.order.notes ?? "N/A"}',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          SafeText(_dateFormat.format(item.order.loadingDate),
                              style: const TextStyle(color: AppTheme.grey)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppTheme.error),
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteOrder(item, db);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // For each customer
                    ...item.customers.map((customer) {
                      final customerItems = groupedItems[customer.id] ?? [];
                      final customerTotal = customerItems.fold<double>(
                          0, (sum, oi) => sum + oi.netAmount);
                      final customerQtl = customerItems.fold<double>(
                          0, (sum, oi) => sum + oi.qtyQtl);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 16),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SafeRow(
                              leading: SafeText(customer.shopName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              trailing: SafeWrap(
                                children: [
                                  SafeText(
                                      '${customerQtl.toStringAsFixed(2)} QTL',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  const SizedBox(width: 8),
                                  SafeText(
                                      '$currency${customerTotal.toStringAsFixed(0)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: theme.primaryColor)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Customer Items
                          ...customerItems.map((oi) {
                            final prod = products.firstWhere(
                                (p) => p.id == oi.productId,
                                orElse: () => _fallbackProd());
                            return Padding(
                              padding:
                                  const EdgeInsets.only(left: 12, bottom: 12),
                              child: SafeRow(
                                leading: SafeColumn(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SafeText(prod.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                    SafeText(
                                        '26kg: ${oi.bags26} | 10kg: ${oi.bags10} | 5kg: ${oi.bags5}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.grey)),
                                  ],
                                ),
                                trailing: SafeColumn(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    SafeText(
                                        '${oi.qtyQtl.toStringAsFixed(2)} QTL',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    SafeText(
                                        '@$currency${oi.ratePerQtl.toStringAsFixed(0)}/QTL',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.grey)),
                                    SafeText(
                                        '$currency${oi.netAmount.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: theme.primaryColor)),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
                      );
                    }),

                    // Variety-wise QTL summary
                    const Divider(height: 32),
                    const SafeText('RICE VARIETY SUMMARY',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    ...[
                      () {
                        final varietyQtls = <String, double>{};
                        for (var oi in orderItems) {
                          final prod = products.firstWhere(
                              (p) => p.id == oi.productId,
                              orElse: () => _fallbackProd());
                          final name = prod.name;
                          varietyQtls[name] =
                              (varietyQtls[name] ?? 0.0) + oi.qtyQtl;
                        }
                        return varietyQtls.entries.map((e) {
                          final pct = orderItems.fold<double>(
                                      0, (s, oi) => s + oi.qtyQtl) >
                                  0
                              ? (e.value /
                                  orderItems.fold<double>(
                                      0, (s, oi) => s + oi.qtyQtl) *
                                  100)
                              : 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: SafeRow(
                              leading: SafeText(e.key,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              trailing: SafeText(
                                  '${e.value.toStringAsFixed(2)} QTL (${pct.toStringAsFixed(0)}%)',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ),
                          );
                        }).toList();
                      }(),
                    ].expand((w) => w),
                    const SizedBox(height: 8),
                    const Divider(height: 16),
                    SafeRow(
                      leading: SafeText('total_value'.tr(ref).toUpperCase(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 1.2)),
                      trailing: SafeColumn(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SafeText(
                              '${orderItems.fold<double>(0, (sum, oi) => sum + oi.qtyQtl).toStringAsFixed(2)} QTL',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          SafeText(
                              '$currency${item.order.totalAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text('done'.tr(ref),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteOrder(OrderWithDetails item, AppDatabase db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('delete_order'.tr(ref)),
        content: Text('delete_order_confirm'.tr(ref)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr(ref)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('delete'.tr(ref)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Phase 4: Auto-backup before manipulation
    await BackupService.backupDatabase();

    try {
      await db.transaction(() async {
        // Delete in correct order: items -> shipments -> payments -> order
        await (db.delete(db.orderItems)
              ..where((t) => t.orderId.equals(item.order.id)))
            .go();
        await (db.delete(db.lorryShipments)
              ..where((t) => t.orderId.equals(item.order.id)))
            .go();
        await (db.delete(db.payments)
              ..where((t) => t.orderId.equals(item.order.id)))
            .go();
        await (db.delete(db.orders)..where((t) => t.id.equals(item.order.id)))
            .go();
      });
      if (mounted) {
        SafeSnackBar.show(context, 'order_deleted'.tr(ref));
      }
    } catch (e) {
      _showError('Delete failed: $e');
    }
  }

  Product _fallbackProd() => Product(
      id: '',
      name: 'Unknown',
      defaultPrice: 0,
      gstRateDefault: 0,
      unit: 'qtl',
      isGalaxy: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now());

  Future<void> _downloadExcel(OrderWithDetails item, AppDatabase db) async {
    setState(() {
      _isProcessing = true;
      _processingOrderId = '${item.order.id}_excel';
    });
    try {
      final orderItems = await (db.select(db.orderItems)
            ..where((tbl) => tbl.orderId.equals(item.order.id)))
          .get();
      final products = await db.select(db.products).get();
      final path = await ExcelService.generateLorryExcel(
          order: item.order,
          customers: item.customers,
          items: orderItems,
          products: products,
          orderNumber: item.order.notes ?? 'N/A',
          settings: ref.read(settingsProvider));
      final finalPath = await ExcelService.copyToDownloads(path,
          customPath: ref.read(settingsProvider).excelSavePath);
      if (mounted) {
        SafeSnackBar.show(context, '${'excel_saved'.tr(ref)}: $finalPath');
      }
    } catch (e) {
      _showError('${'export_failed'.tr(ref)}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingOrderId = null;
        });
      }
    }
  }

  Future<void> _resendEmail(OrderWithDetails item, AppDatabase db) async {
    setState(() {
      _isProcessing = true;
      _processingOrderId = '${item.order.id}_email';
    });
    try {
      final orderItems = await (db.select(db.orderItems)
            ..where((tbl) => tbl.orderId.equals(item.order.id)))
          .get();
      final products = await db.select(db.products).get();
      final settings = ref.read(settingsProvider);
      final path = await ExcelService.generateLorryExcel(
          order: item.order,
          customers: item.customers,
          items: orderItems,
          products: products,
          orderNumber: item.order.notes ?? 'N/A',
          settings: settings);
      await EmailService.shareOrderExcel(
        filePath: path,
        orderNumber: item.order.notes ?? 'N/A',
        loadingDate: item.order.loadingDate,
        agentName: settings.agentName,
        millName: settings.millName,
      );
    } catch (e) {
      _showError('Email failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingOrderId = null;
        });
      }
    }
  }

  Future<void> _sendWhatsApp(OrderWithDetails item, AppDatabase db) async {
    final localization = ref.read(settingsProvider);
    final currency = localization.currencySymbol;

    if (item.customers.isEmpty) return;

    // Helper to send for a specific customer
    Future<void> sendForCustomer(Customer customer) async {
      try {
        final customerItems = await (db.select(db.orderItems)
              ..where((t) =>
                  t.orderId.equals(item.order.id) &
                  t.customerId.equals(customer.id)))
            .get();

        final allProducts = await db.select(db.products).get();

        // Share PDF invoice via system share sheet (WhatsApp, email, etc.)
        await PdfService.generateAndShareInvoice(
          customer: customer,
          items: customerItems,
          products: allProducts,
          order: item.order,
          currencySymbol: currency,
          agentName: localization.agentName,
          millName: localization.millName,
        );
      } catch (e) {
        _showError('Share failed: $e');
      }
    }

    if (item.customers.length == 1) {
      await sendForCustomer(item.customers.first);
    } else {
      // Multi-customer dialog
      await showDialog(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text('whatsapp'.tr(ref)),
          children: [
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final allItems = await (db.select(db.orderItems)
                        ..where((t) => t.orderId.equals(item.order.id)))
                      .get();
                  final allProducts = await db.select(db.products).get();

                  // Fetch customers explicitly to ensure we have them all
                  final customers = await (db.select(db.customers)
                        ..where((t) => t.id
                            .isIn(item.customers.map((c) => c.id).toList())))
                      .get();

                  // Check mounted before WhatsApp call - prevents use after dispose
                  if (!mounted) return;

                  await WhatsAppService.sendLorrySummaryMessage(
                    order: item.order,
                    customers: customers,
                    allItems: allItems,
                    allProducts: allProducts,
                    millContactPhone: localization.millContactPhone,
                    currencySymbol: currency,
                    agentName: localization.agentName,
                    millName: localization.millName,
                  );
                } catch (e) {
                  if (mounted) {
                    _showError('WhatsApp summary failed: $e');
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('whatsapp_summary'.tr(ref),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text('whatsapp_summary_helper'.tr(ref),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Text('select_customer'.tr(ref),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ...item.customers.map((c) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context);
                    sendForCustomer(c);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            c.shopName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      );
    }
  }

  void _showError(String msg) {
    if (mounted) {
      SafeSnackBar.show(context, msg, isError: true);
    }
  }

  void _showSuccess(String msg) {
    if (mounted) {
      SafeSnackBar.show(context, msg);
    }
  }

  void _duplicateOrder(OrderWithDetails item) {
    Navigator.push(
        context,
        fadeSlideRoute(
            NewOrderScreen(duplicateOrderId: item.order.id)));
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.receipt_long_outlined,
      title: 'no_orders'.tr(ref),
      description:
          'New lorry orders will appear here with export and sharing status.',
      actionLabel: 'New Order',
      onAction: () => Navigator.push(
        context,
        fadeSlideRoute(const NewOrderScreen()),
      ),
    );
  }
}
