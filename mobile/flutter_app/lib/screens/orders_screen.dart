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
import 'new_order_screen.dart';

/// Orders History Screen with filters and actions
/// Allows viewing, downloading, resending, and duplicating orders
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
      appBar: AppBar(
        title: const Text('Orders History'),
        actions: [
          // Date filter
          IconButton(
            icon: Icon(
              _filterDate != null
                  ? Icons.event_available
                  : Icons.calendar_today,
              color: _filterDate != null ? AppTheme.primaryGreen : null,
            ),
            tooltip: 'Filter by date',
            onPressed: () => _selectDate(context),
          ),
          // Customer filter
          // Customer filter search
          IconButton(
            icon: Icon(
              _filterCustomer != null ? Icons.person : Icons.person_search,
              color: _filterCustomer != null ? AppTheme.primaryGreen : null,
            ),
            tooltip: 'Search & Filter by Customer',
            onPressed: () {
              showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                      contentPadding: EdgeInsets.zero,
                      content: SizedBox(
                        width: double.maxFinite,
                        child: StreamBuilder<List<Customer>>(
                            stream: db.select(db.customers).watch(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox(
                                    height: 100,
                                    child: Center(
                                        child: CircularProgressIndicator()));
                              }
                              final customers = snapshot.data!;

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: SearchAnchor(
                                      builder: (context, controller) =>
                                          SearchBar(
                                        controller: controller,
                                        hintText: 'Search Name or Phone...',
                                        leading: const Icon(Icons.search),
                                        onChanged: (_) => controller.openView(),
                                        onTap: () => controller.openView(),
                                      ),
                                      suggestionsBuilder:
                                          (context, controller) {
                                        final keyword =
                                            controller.text.toLowerCase();
                                        final filtered = customers
                                            .where((c) =>
                                                c.shopName
                                                    .toLowerCase()
                                                    .contains(keyword) ||
                                                (c.phone ?? '')
                                                    .contains(keyword))
                                            .toList();

                                        return filtered.map((c) => ListTile(
                                              title: Text(c.shopName),
                                              subtitle: c.place != null
                                                  ? Text(c.place!)
                                                  : null,
                                              onTap: () {
                                                setState(
                                                    () => _filterCustomer = c);
                                                controller.closeView(null);
                                                Navigator.pop(context);
                                              },
                                            ));
                                      },
                                    ),
                                  ),
                                  if (_filterCustomer != null)
                                    ListTile(
                                      leading: const Icon(Icons.clear),
                                      title: const Text('Clear Filter'),
                                      onTap: () {
                                        setState(() => _filterCustomer = null);
                                        Navigator.pop(context);
                                      },
                                    )
                                ],
                              );
                            }),
                      )));
            },
          ),
          // Clear filters
          if (_filterDate != null || _filterCustomer != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear filters',
              onPressed: () {
                setState(() {
                  _filterDate = null;
                  _filterCustomer = null;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Active filters display
          if (_filterDate != null || _filterCustomer != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.paleGreen,
              child: Row(
                children: [
                  const Icon(Icons.filter_alt,
                      size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  const Text(
                    'Filters: ',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_filterDate != null)
                    Chip(
                      label: Text(_dateFormat.format(_filterDate!)),
                      onDeleted: () => setState(() => _filterDate = null),
                      deleteIconColor: AppTheme.primaryGreen,
                      side: BorderSide.none,
                      backgroundColor: Colors.white,
                    ),
                  if (_filterCustomer != null) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(_filterCustomer!.shopName),
                      onDeleted: () => setState(() => _filterCustomer = null),
                      deleteIconColor: AppTheme.primaryGreen,
                      side: BorderSide.none,
                      backgroundColor: Colors.white,
                    ),
                  ],
                ],
              ),
            ),

          // Orders List
          Expanded(
            child: StreamBuilder<List<OrderWithDetails>>(
              stream: _buildOrdersQuery(db),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data!;
                if (orders.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final item = orders[index];
                    return _buildOrderCard(item, db);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<OrderWithDetails>> _buildOrdersQuery(AppDatabase db) {
    // 1. Watch orders table (sorted by loading date)
    final ordersStream = (db.select(db.orders)
          ..orderBy([
            (t) => drift.OrderingTerm(
                expression: t.loadingDate, mode: drift.OrderingMode.desc)
          ]))
        .watch();

    return ordersStream.asyncMap((orders) async {
      if (orders.isEmpty) return [];

      // 2. Fetch all lorry shipments for these orders in one batch
      final orderIds = orders.map((o) => o.id).toList();
      final shipmentRows = await (db.select(db.lorryShipments).join([
        drift.innerJoin(db.customers,
            db.customers.id.equalsExp(db.lorryShipments.customerId)),
      ])
            ..where(db.lorryShipments.orderId.isIn(orderIds)))
          .get();

      // 3. Optional: Fetch legacy customers if needed
      final legacyOrderIds =
          orders.where((o) => o.customerId != null).map((o) => o.id).toList();
      Map<String, Customer> legacyCustomers = {};
      if (legacyOrderIds.isNotEmpty) {
        final legacyRows = await (db.select(db.orders).join([
          drift.innerJoin(
              db.customers, db.customers.id.equalsExp(db.orders.customerId)),
        ])
              ..where(db.orders.id.isIn(legacyOrderIds)))
            .get();
        for (var row in legacyRows) {
          legacyCustomers[row.readTable(db.orders).id] =
              row.readTable(db.customers);
        }
      }

      // 4. Group customers by order ID
      final orderCustomers = <String, List<Customer>>{};
      for (var row in shipmentRows) {
        final oId = row.readTable(db.lorryShipments).orderId;
        final customer = row.readTable(db.customers);
        orderCustomers.putIfAbsent(oId, () => []).add(customer);
      }

      // Add legacy customers
      legacyCustomers.forEach((oId, customer) {
        if (!orderCustomers.containsKey(oId)) {
          orderCustomers[oId] = [customer];
        }
      });

      // 5. Build final list
      final results = orders.map((order) {
        return OrderWithDetails(
          order: order,
          customers: orderCustomers[order.id] ?? [],
        );
      }).toList();

      // 6. Apply manual filters (could be optimized further in query)
      var filtered = results;
      if (_filterDate != null) {
        filtered = filtered
            .where((item) =>
                item.order.loadingDate.year == _filterDate!.year &&
                item.order.loadingDate.month == _filterDate!.month &&
                item.order.loadingDate.day == _filterDate!.day)
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

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _filterDate = picked);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: Lottie.asset(
              'assets/lottie/empty.json',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _filterDate != null || _filterCustomer != null
                ? 'No orders match filters'
                : 'No orders yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.darkGrey,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders will appear here after creation',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.grey,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderWithDetails item, AppDatabase db) {
    final order = item.order;
    final customer = item.customers.first;

    return Card(
      margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
      child: InkWell(
        onTap: () => _showOrderDetails(item, db),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.paleGreen,
                    child: Text(
                      customer.shopName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          customer.place ?? "N/A",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${order.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _dateFormat.format(order.loadingDate),
                        style:
                            const TextStyle(fontSize: 10, color: AppTheme.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Actions - Scrollable to prevent overflow on small screens
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildActionButton(
                      icon: Icons.download,
                      label: 'Excel', // Shortened label
                      onTap: () => _downloadExcel(item, db),
                    ),
                    _buildActionButton(
                      icon: Icons.mail_rounded,
                      label: 'Mail', // Shortened label
                      onTap: () => _resendEmail(item, db),
                    ),
                    _buildActionButton(
                      icon: Icons.copy,
                      label: 'Clone', // Shortened label
                      onTap: () => _duplicateOrder(item),
                    ),
                    if (item.customers.length == 1)
                      _buildActionButton(
                        icon: Icons.send_rounded,
                        label: 'WhatsApp',
                        onTap: () async {
                          final orderItems = await (db.select(db.orderItems)
                                ..where(
                                    (tbl) => tbl.orderId.equals(item.order.id)))
                              .get();
                          final products = await db.select(db.products).get();

                          if (!mounted) return;

                          try {
                            await WhatsAppService.sendOrderMessage(
                              customer: item.customers.first,
                              order: item.order,
                              items: orderItems,
                              products: products,
                            );
                          } catch (e) {
                            _showError(e.toString());
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryGreen, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Text(
                item.customers.isNotEmpty
                    ? item.customers.first.shopName
                    : 'Lorry Load',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                'Lorry Order: ${item.order.notes ?? "N/A"}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.grey,
                    ),
              ),
              const SizedBox(height: 20),

              // Items
              Text(
                'Order Items',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ...orderItems.map((orderItem) {
                final product = products.firstWhere(
                  (p) => p.id == orderItem.productId,
                  orElse: () => Product(
                    id: '',
                    name: 'Unknown',
                    defaultPrice: 0,
                    gstRateDefault: 0,
                    unit: 'qtl',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                );
                return Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '26kg: ${orderItem.bags26} | 10kg: ${orderItem.bags10} | 5kg: ${orderItem.bags5}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${orderItem.qtyQtl.toStringAsFixed(2)} QTL',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '₹${orderItem.netAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              // WhatsApp Section
              Text(
                'Send Updates',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ...item.customers.map((customer) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final customerItems = orderItems
                              .where((oi) => oi.customerId == customer.id)
                              .toList();
                          await WhatsAppService.sendOrderMessage(
                            customer: customer,
                            order: item.order,
                            items: customerItems,
                            products: products,
                          );
                        } catch (e) {
                          _showError('WhatsApp Error: $e');
                        }
                      },
                      icon: const Icon(Icons.send_rounded, color: Colors.green),
                      label: Text('Send to ${customer.shopName} (WhatsApp)'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        foregroundColor: Colors.green,
                      ),
                    ),
                  )),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    '₹${item.order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadExcel(OrderWithDetails item, AppDatabase db) async {
    try {
      final orderItems = await (db.select(db.orderItems)
            ..where((tbl) => tbl.orderId.equals(item.order.id)))
          .get();
      final products = await db.select(db.products).get();

      final filePath = await ExcelService.generateLorryExcel(
        order: item.order,
        customers: item.customers,
        items: orderItems,
        products: products,
        orderNumber: item.order.notes ?? 'N/A',
      );

      // Copy to downloads
      await ExcelService.copyToDownloads(filePath);

      if (mounted) {
        _showSuccess('Excel saved to Downloads');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _resendEmail(OrderWithDetails item, AppDatabase db) async {
    try {
      final orderItems = await (db.select(db.orderItems)
            ..where((tbl) => tbl.orderId.equals(item.order.id)))
          .get();
      final products = await db.select(db.products).get();

      final filePath = await ExcelService.generateLorryExcel(
        order: item.order,
        customers: item.customers,
        items: orderItems,
        products: products,
        orderNumber: item.order.notes ?? 'N/A',
      );

      await EmailService.shareOrderExcel(
        filePath: filePath,
        customerName: item.customers.length > 1
            ? 'Lorry Load'
            : (item.customers.isNotEmpty
                ? item.customers.first.shopName
                : 'Customer'),
        orderNumber: item.order.notes ?? 'N/A',
      );
    } catch (e) {
      _showError('Error: $e');
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
        builder: (_) => NewOrderScreen(
          duplicateOrderId: item.order.id, // Pass ID for full duplication
        ),
      ),
    );
  }
}

/// Helper class for order with customer details
class OrderWithDetails {
  final Order order;
  final List<Customer> customers;

  OrderWithDetails({required this.order, required this.customers});
}
