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

/// Orders History Screen with filters and actions
/// REFACTORED FOR STABILITY - NO OVERFLOW ERRORS
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  DateTime? _filterDate;
  Customer? _filterCustomer;
  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const SafeText('Orders History', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(
                _filterDate != null
                    ? Icons.event_available
                    : Icons.calendar_today,
                color: _filterDate != null ? AppTheme.primaryGreen : null),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: Icon(
                _filterCustomer != null ? Icons.person : Icons.person_search,
                color: _filterCustomer != null ? AppTheme.primaryGreen : null),
            onPressed: () => _showCustomerFilter(context, db),
          ),
          if (_filterDate != null || _filterCustomer != null)
            IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: () => setState(() {
                      _filterDate = null;
                      _filterCustomer = null;
                    })),
        ],
      ),
      body: SafeColumn(
        children: [
          if (_filterDate != null || _filterCustomer != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppTheme.paleGreen,
              child: SafeWrap(
                children: [
                  const Icon(Icons.filter_alt,
                      size: 16, color: AppTheme.primaryGreen),
                  if (_filterDate != null)
                    Chip(
                        label: Text(_dateFormat.format(_filterDate!)),
                        onDeleted: () => setState(() => _filterDate = null)),
                  if (_filterCustomer != null)
                    Chip(
                        label: Text(_filterCustomer!.shopName),
                        onDeleted: () =>
                            setState(() => _filterCustomer = null)),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<OrderWithDetails>>(
              stream: _buildOrdersQuery(db),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final orders = snapshot.data!;
                if (orders.isEmpty) return _buildEmptyState();
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) =>
                      _buildOrderCard(orders[index], db),
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
      if (_filterCustomer != null) {
        filtered = filtered
            .where((item) =>
                item.customers.any((c) => c.id == _filterCustomer!.id))
            .toList();
      }
      return filtered;
    });
  }

  Widget _buildOrderCard(OrderWithDetails item, AppDatabase db) {
    final customer = item.customers.isNotEmpty ? item.customers.first : null;
    return SafeCard(
      padding: EdgeInsets.zero,
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
                    backgroundColor: AppTheme.paleGreen,
                    child: Text(customer?.shopName[0] ?? 'L',
                        style: const TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold)),
                  ),
                  trailing: SafeColumn(
                    children: [
                      SafeText(customer?.shopName ?? "Multi-Customer Lorry",
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
                    SafeText('₹${item.order.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    SafeText(item.order.notes ?? 'No #',
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
                    _actionBtn(Icons.download, 'Excel',
                        () => _downloadExcel(item, db)),
                    _actionBtn(
                        Icons.email, 'Email', () => _resendEmail(item, db)),
                    _actionBtn(
                        Icons.copy, 'Clone', () => _duplicateOrder(item)),
                    if (item.customers.length == 1)
                      _actionBtn(Icons.send, 'WhatsApp',
                          () => _sendWhatsApp(item, db)),
                    _actionBtn(Icons.delete_outline, 'Delete',
                        () => _confirmDeleteOrder(item, db),
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

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap,
      {bool isError = false}) {
    final color = isError ? AppTheme.error : AppTheme.primaryGreen;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SafeColumn(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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
        title: const Text('Delete Order?'),
        content: Text(
            'Are you sure you want to delete order "${item.order.notes ?? item.order.id}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
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
        _showSuccess('Order deleted successfully');
      } catch (e) {
        _showError('Failed to delete order: $e');
      }
    }
  }

  Future<void> _showOrderDetails(OrderWithDetails item, AppDatabase db) async {
    final orderItems = await (db.select(db.orderItems)
          ..where((tbl) => tbl.orderId.equals(item.order.id)))
        .get();
    final products = await db.select(db.products).get();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, controller) => SafePage(
          child: SafeColumn(
            children: [
              SafeText(
                  item.customers.isNotEmpty
                      ? item.customers.first.shopName
                      : 'Lorry Order',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              SafeText('Order No: ${item.order.notes ?? "N/A"}',
                  style: const TextStyle(color: AppTheme.grey)),
              const SizedBox(height: 20),
              ...orderItems.map((oi) {
                final prod = products.firstWhere((p) => p.id == oi.productId,
                    orElse: () => _fallbackProd());
                return SafeCard(
                  color: AppTheme.lightGrey,
                  child: SafeRow(
                    leading: SafeColumn(
                      children: [
                        SafeText(prod.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        SafeText(
                            '26kg: ${oi.bags26} | 10kg: ${oi.bags10} | 5kg: ${oi.bags5}',
                            style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                    trailing: SafeColumn(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SafeText('${oi.qtyQtl.toStringAsFixed(2)} QTL',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        SafeText('₹${oi.netAmount.toStringAsFixed(0)}',
                            style:
                                const TextStyle(color: AppTheme.primaryGreen)),
                      ],
                    ),
                  ),
                );
              }),
              const Divider(height: 32),
              SafeRow(
                leading: const Text('TOTAL AMOUNT',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                trailing: SafeText(
                    '₹${item.order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))),
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

  void _showCustomerFilter(BuildContext context, AppDatabase db) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Customer'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<Customer>>(
            stream: db.select(db.customers).watch(),
            builder: (context, snapshot) {
              final customers = snapshot.data ?? [];
              return ListView.builder(
                shrinkWrap: true,
                itemCount: customers.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(customers[index].shopName),
                  onTap: () {
                    setState(() => _filterCustomer = customers[index]);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _downloadExcel(OrderWithDetails item, AppDatabase db) async {
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
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Excel saved to Downloads'),
          backgroundColor: AppTheme.success));
  }

  Future<void> _resendEmail(OrderWithDetails item, AppDatabase db) async {
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
        customerName:
            item.customers.isNotEmpty ? item.customers.first.shopName : 'Lorry',
        orderNumber: item.order.notes ?? 'N/A');
  }

  Future<void> _sendWhatsApp(OrderWithDetails item, AppDatabase db) async {
    final orderItems = await (db.select(db.orderItems)
          ..where((tbl) => tbl.orderId.equals(item.order.id)))
        .get();
    final products = await db.select(db.products).get();
    await WhatsAppService.sendOrderMessage(
        customer: item.customers.first,
        order: item.order,
        items: orderItems,
        products: products);
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

  Widget _buildEmptyState() {
    return Center(
        child:
            SafeColumn(mainAxisAlignment: MainAxisAlignment.center, children: [
      Lottie.asset('assets/lottie/empty.json', width: 180),
      const SizedBox(height: 16),
      const SafeText('No orders found')
    ]));
  }
}

class OrderWithDetails {
  final Order order;
  final List<Customer> customers;
  OrderWithDetails({required this.order, required this.customers});
}
