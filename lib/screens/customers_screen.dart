import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../main.dart';
import '../theme.dart';

import '../db/database.dart';
import '../services/translation_service.dart';
import '../widgets/safe_widgets.dart';
import '../widgets/customer_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/search_bar_widget.dart';
import 'new_order_screen.dart';
import '../services/excel_service.dart';
import '../providers/settings_provider.dart';
import '../services/backup_service.dart';

String? _validateGstin(String? value) {
  if (value == null || value.isEmpty) return null;
  final cleaned = value.trim().toUpperCase();
  if (cleaned.length != 15) return 'GSTIN must be exactly 15 characters';
  if (!RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$')
      .hasMatch(cleaned)) {
    return 'Invalid GSTIN format';
  }
  return null;
}

String? _validatePhone(String? value) {
  if (value == null || value.isEmpty) return null;
  final cleaned = value.replaceAll(RegExp(r'\D'), '');
  if (cleaned.isEmpty) return null;
  if (cleaned.length < 10) return 'Phone number must have at least 10 digits';
  return null;
}

/// Screen for managing customers with full CRUD operations
/// REFACTORED FOR STABILITY - NO OVERFLOW ERRORS
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  Stream<List<Customer>>? _customersStream;

  // Cache: customerId → { totalQtl, records }
  Map<String, _CustomerPurchaseData> _purchaseCache = {};
  bool _purchaseCacheLoaded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();

  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);
    _customersStream ??= db.select(db.customers).watch();

    // Load purchase data lazily (once)
    if (!_purchaseCacheLoaded) {
      _purchaseCacheLoaded = true;
      _loadPurchaseData(db);
    }


    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title:
            SafeText('customers'.tr(ref), style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'import_excel'.tr(ref),
            onPressed: () => _importExcel(db),
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Export All Customers',
            onPressed: () => _exportAllCustomers(db),
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'add_customer'.tr(ref),
            onPressed: () => _showCustomerDialog(context, db),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SearchBarWidget(
                controller: _searchController,
                hintText: 'search_hint'.tr(ref),
                onClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                onChanged: (value) {
                  // Trim + collapse whitespace to handle " AKKAYYAPALEM " vs "AKKAYYAPALEM"
                  setState(() => _searchQuery =
                      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '));
                },
              ),
            ),

            Expanded(
              child: StreamBuilder<List<Customer>>(
                stream: _customersStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var customers = snapshot.data!;

                  customers.sort((a, b) {
                    final aPlace = a.place?.trim().toLowerCase() ?? '';
                    final bPlace = b.place?.trim().toLowerCase() ?? '';
                    if (aPlace.isEmpty && bPlace.isNotEmpty) return 1;
                    if (aPlace.isNotEmpty && bPlace.isEmpty) return -1;
                    final placeCompare = aPlace.compareTo(bPlace);
                    if (placeCompare != 0) return placeCompare;
                    return a.shopName
                        .toLowerCase()
                        .compareTo(b.shopName.toLowerCase());
                  });

                  if (_searchQuery.isNotEmpty) {
                    final queryTokens = _searchQuery.split(' ').where((t) => t.isNotEmpty).toList();
                    customers = customers.where((c) {
                      // Normalise each field the same way the query was normalised
                      String norm(String? s) =>
                          (s ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
                      // Combine all searchable fields into one string
                      final combined = '${norm(c.shopName)} ${norm(c.phone)} ${norm(c.ownerName)} ${norm(c.place)} ${norm(c.tinGst)}';
                      // Every query token must appear somewhere in the combined text
                      return queryTokens.every((token) => combined.contains(token));
                    }).toList();
                  }

                  if (customers.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      return _buildCustomerCard(customers[index], db);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: _searchQuery.isEmpty
          ? Icons.people_outline
          : Icons.search_off_outlined,
      title:
          _searchQuery.isEmpty ? 'no_customers'.tr(ref) : 'none_found'.tr(ref),
      description: _searchQuery.isEmpty
          ? 'add_first'.tr(ref)
          : 'Try a different customer name, place, GSTIN, or phone number.',
      actionLabel: _searchQuery.isEmpty ? 'add_customer'.tr(ref) : null,
      onAction: _searchQuery.isEmpty
          ? () => _showCustomerDialog(context, ref.read(databaseProvider))
          : null,
    );
  }

  Widget _buildCustomerCard(Customer customer, AppDatabase db) {
    final data = _purchaseCache[customer.id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomerCard(
        customer: customer,
        totalQtl: data?.totalQtl ?? 0.0,
        purchaseHistory: data?.records ?? const [],
        onTap: () => _navigateToNewOrder(customer),
        onEdit: () => _showCustomerDialog(context, db, customer: customer),
        onDelete: () => _confirmDelete(customer, db),
      ),
    );
  }

  void _navigateToNewOrder(Customer customer) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => NewOrderScreen(preselectedCustomer: customer)));
  }

  Future<void> _confirmDelete(Customer customer, AppDatabase db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: SafeText('delete_customer'.tr(ref)),
        content: SafeText('delete_customer_confirm'.tr(ref)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr(ref))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
              child: Text('delete'.tr(ref))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Auto-backup before destructive operation
        await BackupService.backupDatabase();

        // Background consolidated backup
        await ExcelService.appendDeletedCustomer(customer,
            customPath: ref.read(settingsProvider).excelSavePath);

        await db.transaction(() async {
          // 1. Find all orders this customer is part of
          final affectedShipments = await (db.select(db.lorryShipments)
                ..where((tbl) => tbl.customerId.equals(customer.id)))
              .get();
          final affectedOrderIds =
              affectedShipments.map((s) => s.orderId).toSet();

          // 2. Delete customer's order items and shipments
          await (db.delete(db.orderItems)
                ..where((tbl) => tbl.customerId.equals(customer.id)))
              .go();
          await (db.delete(db.lorryShipments)
                ..where((tbl) => tbl.customerId.equals(customer.id)))
              .go();

          // 3. Recalculate totals for each affected order
          for (final orderId in affectedOrderIds) {
            final remainingItems = await (db.select(db.orderItems)
                  ..where((tbl) => tbl.orderId.equals(orderId)))
                .get();

            if (remainingItems.isEmpty) {
              // Order is now empty — delete it and its payments
              await (db.delete(db.payments)
                    ..where((tbl) => tbl.orderId.equals(orderId)))
                  .go();
              await (db.delete(db.orders)..where((tbl) => tbl.id.equals(orderId)))
                  .go();
            } else {
              // Recalculate total from remaining items
              final newTotal =
                  remainingItems.fold(0.0, (sum, item) => sum + item.netAmount);
              await (db.update(db.orders)..where((tbl) => tbl.id.equals(orderId)))
                  .write(OrdersCompanion(
                totalAmount: drift.Value(newTotal),
                updatedAt: drift.Value(DateTime.now()),
              ));
            }
          }

          // 4. Delete customer prices and the customer itself
          await (db.delete(db.customerPrices)
                ..where((tbl) => tbl.customerId.equals(customer.id)))
              .go();
          await (db.delete(db.customers)
                ..where((tbl) => tbl.id.equals(customer.id)))
              .go();
        });

        if (mounted) {
          SafeSnackBar.show(context, 'deleted'.tr(ref));
        }
      } catch (e) {
        if (mounted) {
          SafeSnackBar.show(context, '${'failed_to_delete'.tr(ref)}: $e',
              isError: true);
        }
      }
    }
  }

  void _showCustomerDialog(BuildContext context, AppDatabase db,
      {Customer? customer}) {
    final isEditing = customer != null;
    final shopNameController =
        TextEditingController(text: customer?.shopName ?? '');
    final placeController = TextEditingController(text: customer?.place ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final gstController = TextEditingController(text: customer?.tinGst ?? '');
    String? phoneError;
    String? gstError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(
              isEditing ? 'edit_customer'.tr(ref) : 'add_customer'.tr(ref)),
          content: SingleChildScrollView(
            child: SafeColumn(
              children: [
                TextField(
                    controller: shopNameController,
                    decoration: InputDecoration(
                        labelText: '${'shop_name'.tr(ref)} *',
                        prefixIcon: const Icon(Icons.store)),
                    textCapitalization: TextCapitalization.words),
                const SizedBox(height: 12),
                TextField(
                    controller: placeController,
                    decoration: InputDecoration(
                        labelText: 'place'.tr(ref),
                        prefixIcon: const Icon(Icons.location_on)),
                    textCapitalization: TextCapitalization.words),
                const SizedBox(height: 12),
                TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                        labelText: 'phone'.tr(ref),
                        prefixIcon: const Icon(Icons.phone),
                        errorText: phoneError),
                    keyboardType: TextInputType.phone,
                    onChanged: (_) {
                      setDialogState(() {
                        phoneError = _validatePhone(phoneController.text);
                      });
                    }),
                const SizedBox(height: 12),
                TextField(
                    controller: gstController,
                    decoration: InputDecoration(
                        labelText: 'GST / TIN',
                        prefixIcon: const Icon(Icons.receipt),
                        errorText: gstError),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) {
                      setDialogState(() {
                        gstError = _validateGstin(gstController.text);
                      });
                    }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('cancel'.tr(ref))),
            FilledButton(
              onPressed: () async {
                if (shopNameController.text.trim().isEmpty) return;
                final phoneErr = _validatePhone(phoneController.text);
                final gstErr = _validateGstin(gstController.text);
                setDialogState(() {
                  phoneError = phoneErr;
                  gstError = gstErr;
                });
                if (phoneErr != null || gstErr != null) return;
                final companion = CustomersCompanion(
                  shopName: drift.Value(shopNameController.text.trim()),
                  place: drift.Value(placeController.text.trim()),
                  phone: drift.Value(phoneController.text.trim()),
                  tinGst: drift.Value(gstController.text.trim()),
                  updatedAt: drift.Value(DateTime.now()),
                );
                if (isEditing) {
                  await (db.update(db.customers)
                        ..where((tbl) => tbl.id.equals(customer.id)))
                      .write(companion);
                } else {
                  await db.into(db.customers).insert(
                      companion.copyWith(id: drift.Value(generateId())));
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(isEditing ? 'update'.tr(ref) : 'save'.tr(ref)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importExcel(AppDatabase db) async {
    final scaffold = ScaffoldMessenger.of(context);
    final result = await ExcelService.importCustomersFromExcel(db);
    if (!mounted) return;

    if (result['success'] == true) {
      scaffold.showSnackBar(SnackBar(
        content: Text(result['message']),
        backgroundColor: AppTheme.success,
      ));
    } else {
      if (result['message'] != 'No file selected') {
        scaffold.showSnackBar(SnackBar(
          content: Text(result['message']),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  Future<void> _exportAllCustomers(AppDatabase db) async {
    final scaffold = ScaffoldMessenger.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final customers = await db.select(db.customers).get();
      final allItems = await db.select(db.orderItems).get();
      final allOrders = await db.select(db.orders).get();
      final allProducts = await db.select(db.products).get();

      final filePath = await ExcelService.exportAllCustomerPurchases(
        customers: customers,
        orderItems: allItems,
        orders: allOrders,
        products: allProducts,
        customPath: ref.read(settingsProvider).excelSavePath,
      );

      if (mounted) Navigator.pop(context); // dismiss loading

      final downloadPath = await ExcelService.copyToDownloads(
        filePath,
        customPath: ref.read(settingsProvider).excelSavePath,
      );

      scaffold.showSnackBar(SnackBar(
        content: Text('Customer report exported: ${downloadPath.split('/').last}'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      if (mounted) Navigator.pop(context); // dismiss loading
      scaffold.showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  /// Fetches all order items and builds per-customer purchase summary
  Future<void> _loadPurchaseData(AppDatabase db) async {
    try {
      // Get all order items
      final allItems = await db.select(db.orderItems).get();
      if (allItems.isEmpty) return;

      // Get all orders for date + order number
      final allOrders = await db.select(db.orders).get();
      final orderMap = {for (final o in allOrders) o.id: o};

      // Get all products for variety name
      final allProducts = await db.select(db.products).get();
      final productMap = {for (final p in allProducts) p.id: p};

      // Build the cache
      final cache = <String, _CustomerPurchaseData>{};

      for (final item in allItems) {
        final order = orderMap[item.orderId];
        final product = productMap[item.productId];
        if (order == null || product == null) continue;

        final record = PurchaseRecord(
          orderNo: order.notes ?? order.id.substring(0, 6),
          date: order.loadingDate,
          variety: product.name,
          qtyQtl: item.qtyQtl,
          bags26: item.bags26,
          bags10: item.bags10,
          bags5: item.bags5,
        );

        cache.putIfAbsent(
          item.customerId,
          () => _CustomerPurchaseData(totalQtl: 0.0, records: []),
        );
        cache[item.customerId]!.totalQtl += item.qtyQtl;
        cache[item.customerId]!.records.add(record);
      }

      // Sort each customer's records by date (newest first)
      for (final entry in cache.values) {
        entry.records.sort((a, b) => b.date.compareTo(a.date));
      }

      if (mounted) {
        setState(() => _purchaseCache = cache);
      }
    } catch (_) {
      // Non-critical — silently fail, badge just won't show
    }
  }
}

/// Internal data holder for per-customer purchase aggregation
class _CustomerPurchaseData {
  double totalQtl;
  final List<PurchaseRecord> records;

  _CustomerPurchaseData({required this.totalQtl, required this.records});
}
