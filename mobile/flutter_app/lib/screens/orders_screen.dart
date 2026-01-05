import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../theme.dart';
import '../db/database.dart';
import '../services/excel_service.dart';
import '../services/email_service.dart';
import '../services/whatsapp_service.dart';
import '../widgets/safe_widgets.dart';
import 'new_order_screen.dart';
import '../services/translation_service.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/settings_provider.dart';

/// Orders History Screen with filters and actions
/// REFACTORED FOR STABILITY - NO OVERFLOW ERRORS
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  DateTime? _filterDate;
  String _searchQuery = '';
  final _dateFormat = DateFormat('dd MMM yyyy');
  final _searchController = TextEditingController();
  bool _isProcessing = false;
  String? _processingOrderId;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: SafeText('order_history'.tr(ref),
            style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(
                _filterDate != null
                    ? Icons.event_available
                    : Icons.calendar_today,
                color: _filterDate != null ? theme.primaryColor : null),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'export_all'.tr(ref),
            onPressed: () => _exportAllOrders(db),
          ),
          if (_filterDate != null)
            IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: () => setState(() {
                      _filterDate = null;
                    })),
        ],
      ),
      body: Column(
        children: [
          if (_filterDate != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: theme.primaryColor.withValues(alpha: 0.1),
              child: SafeWrap(
                children: [
                  Icon(Icons.filter_alt, size: 16, color: theme.primaryColor),
                  if (_filterDate != null)
                    Chip(
                        label: Text(_dateFormat.format(_filterDate!)),
                        onDeleted: () => setState(() => _filterDate = null)),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<OrderWithDetails>>(
              stream: _buildOrdersQuery(db),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final orders = snapshot.data!;
                if (orders.isEmpty) return _buildEmptyState();

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
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: orders.length,
                        itemBuilder: (context, index) =>
                            _buildOrderCard(orders[index], db),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<OrderWithDetails>> _buildOrdersQuery(AppDatabase db) {
    final ordersStream = (db.select(db.orders)
          ..orderBy([
            (t) => drift.OrderingTerm(
                expression: t.loadingDate, mode: drift.OrderingMode.desc)
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

      final results = orders
          .map((order) => OrderWithDetails(
              order: order, customers: orderCustomers[order.id] ?? []))
          .toList();
      var filtered = results;
      if (_filterDate != null) {
        filtered = filtered
            .where((item) =>
                item.order.loadingDate.day == _filterDate!.day &&
                item.order.loadingDate.month == _filterDate!.month &&
                item.order.loadingDate.year == _filterDate!.year)
            .toList();
      }
      if (_searchQuery.isNotEmpty) {
        filtered = filtered.where((item) {
          final q = _searchQuery.toLowerCase();
          final orderNo = (item.order.notes ?? '').toLowerCase();
          final customers =
              item.customers.map((c) => c.shopName.toLowerCase()).join(' ');
          return orderNo.contains(q) || customers.contains(q);
        }).toList();
      }
      return filtered;
    });
  }

  Widget _buildOrderCard(OrderWithDetails item, AppDatabase db) {
    final theme = Theme.of(context);
    final customer = item.customers.isNotEmpty ? item.customers.first : null;
    return SafeCard(
      padding: EdgeInsets.zero,
      color: theme.cardColor,
      child: InkWell(
        onTap: () => _showOrderDetails(item, db),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SafeColumn(
            children: [
              SafeRow(
                leading: SafeRow(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                    child: Text(customer?.shopName[0] ?? 'L',
                        style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold)),
                  ),
                  trailing: SafeColumn(
                    children: [
                      SafeText(item.order.notes ?? 'no_order_no'.tr(ref),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      SafeText(_dateFormat.format(item.order.loadingDate),
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.grey)),
                    ],
                  ),
                ),
                trailing: SafeColumn(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SafeText(
                        '${ref.watch(settingsProvider).currencySymbol}${item.order.totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    SafeText(
                        customer?.shopName ?? 'multi_customer_lorry'.tr(ref),
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.grey)),
                  ],
                ),
              ),
              const Divider(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _actionBtn(Icons.edit, 'edit'.tr(ref),
                        _isProcessing ? null : () => _duplicateOrder(item)),
                    _actionBtn(Icons.download, 'excel'.tr(ref),
                        _isProcessing ? null : () => _downloadExcel(item, db),
                        isLoading:
                            _processingOrderId == '${item.order.id}_excel'),
                    _actionBtn(Icons.email, 'email'.tr(ref),
                        _isProcessing ? null : () => _resendEmail(item, db),
                        isLoading:
                            _processingOrderId == '${item.order.id}_email'),
                    _actionBtn(Icons.send, 'whatsapp'.tr(ref),
                        _isProcessing ? null : () => _sendWhatsApp(item, db)),
                    _actionBtn(
                        Icons.delete_outline,
                        'delete'.tr(ref),
                        _isProcessing
                            ? null
                            : () => _confirmDeleteOrder(item, db),
                        isError: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback? onTap,
      {bool isError = false, bool isLoading = false}) {
    final theme = Theme.of(context);
    final color = onTap == null
        ? AppTheme.grey
        : (isError ? AppTheme.error : theme.primaryColor);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SafeColumn(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.primaryColor,
                ),
              )
            else
              Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            SafeText(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteOrder(
      OrderWithDetails item, AppDatabase db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
          // 3. Delete the order itself
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
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        expand: false,
        builder: (context, controller) => SafePage(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              SafeText('${'order_no'.tr(ref)}: ${item.order.notes ?? "N/A"}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              SafeText(_dateFormat.format(item.order.loadingDate),
                  style: const TextStyle(color: AppTheme.grey)),
              const SizedBox(height: 20),

              // For each customer
              ...item.customers.map((customer) {
                final customerItems = groupedItems[customer.id] ?? [];
                final customerTotal = customerItems.fold<double>(
                    0, (sum, oi) => sum + oi.netAmount);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SafeRow(
                        leading: SafeText(customer.shopName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        trailing: SafeText(
                            '$currency${customerTotal.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor)),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Customer Items
                    ...customerItems.map((oi) {
                      final prod = products.firstWhere(
                          (p) => p.id == oi.productId,
                          orElse: () => _fallbackProd());
                      return Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 8),
                        child: SafeRow(
                          leading: SafeColumn(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SafeText(prod.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              SafeText(
                                  '26kg: ${oi.bags26} | 10kg: ${oi.bags10} | 5kg: ${oi.bags5}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.grey)),
                            ],
                          ),
                          trailing: SafeColumn(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SafeText('${oi.qtyQtl.toStringAsFixed(2)} QTL',
                                  style: const TextStyle(fontSize: 12)),
                              SafeText(
                                  '$currency${oi.netAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                );
              }),

              const Divider(height: 32),
              SafeRow(
                leading: SafeText('total_value'.tr(ref).toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                trailing: SafeText(
                    '$currency${item.order.totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('close'.tr(ref)))),
            ],
          ),
        ),
      ),
    );
  }

  Product _fallbackProd() => Product(
      id: '',
      name: 'Unknown',
      defaultPrice: 0,
      gstRateDefault: 0,
      unit: 'qtl',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now());

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _filterDate ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (picked != null) setState(() => _filterDate = picked);
  }

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
          orderNumber: item.order.notes ?? 'N/A');
      await ExcelService.copyToDownloads(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('excel_saved'.tr(ref)),
            backgroundColor: AppTheme.success));
      }
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
      final path = await ExcelService.generateLorryExcel(
          order: item.order,
          customers: item.customers,
          items: orderItems,
          products: products,
          orderNumber: item.order.notes ?? 'N/A');
      await EmailService.shareOrderExcel(
          filePath: path,
          customerName: item.customers.isNotEmpty
              ? item.customers.first.shopName
              : 'Lorry',
          orderNumber: item.order.notes ?? 'N/A');
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
      final customerItems = await (db.select(db.orderItems)
            ..where((t) =>
                t.orderId.equals(item.order.id) &
                t.customerId.equals(customer.id)))
          .get();

      final allProducts = await db.select(db.products).get();

      WhatsAppService.sendOrderMessage(
        customer: customer,
        items: customerItems,
        products: allProducts,
        order: item.order,
        currencySymbol: currency,
      );
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
                final allItems = await (db.select(db.orderItems)
                      ..where((t) => t.orderId.equals(item.order.id)))
                    .get();
                final allProducts = await db.select(db.products).get();

                // Fetch customers explicitly to ensure we have them all
                final customers = await (db.select(db.customers)
                      ..where((t) =>
                          t.id.isIn(item.customers.map((c) => c.id).toList())))
                    .get();

                WhatsAppService.sendLorrySummaryMessage(
                  order: item.order,
                  customers: customers,
                  allItems: allItems,
                  allProducts: allProducts,
                  millContactPhone: '9848135359', // Sri Balaji Mill
                  currencySymbol: currency,
                );
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
                        Text(c.shopName),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
      );
    }
  }

  void _showSuccess(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.success),
      );
    }
  }

  void _duplicateOrder(OrderWithDetails item) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => NewOrderScreen(duplicateOrderId: item.order.id)));
  }

  Future<void> _exportAllOrders(AppDatabase db) async {
    try {
      // Get all current orders in the stream (using the same query filter)
      final orders = await _buildOrdersQuery(db).first;
      if (orders.isEmpty) {
        _showError('No orders to export');
        return;
      }

      final products = await db.select(db.products).get();
      final path = await ExcelService.generateAllOrdersExcel(
          orders: orders, products: products);

      await Share.shareXFiles([XFile(path)], text: 'orders_statement'.tr(ref));
      _showSuccess('saved_successfully'.tr(ref));
    } catch (e) {
      _showError('${'export_failed'.tr(ref)}: $e');
    }
  }

  Widget _buildEmptyState() {
    return Center(
        child:
            SafeColumn(mainAxisAlignment: MainAxisAlignment.center, children: [
      Lottie.asset('assets/lottie/empty.json', width: 180),
      const SizedBox(height: 16),
      SafeText('no_orders'.tr(ref))
    ]));
  }
}
