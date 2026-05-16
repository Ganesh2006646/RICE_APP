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

enum _CustomerFilter { all, name, place, phone }

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _CustomerFilter _filter = _CustomerFilter.all;
  final Map<String, GlobalKey> _letterKeys = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);

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
                onChanged: (value) =>
                    setState(() => _searchQuery = value.toLowerCase()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                        'All', _CustomerFilter.all, Icons.all_inclusive),
                    const SizedBox(width: 8),
                    _filterChip('Name', _CustomerFilter.name, Icons.store),
                    const SizedBox(width: 8),
                    _filterChip(
                        'Place', _CustomerFilter.place, Icons.location_on),
                    const SizedBox(width: 8),
                    _filterChip('Phone', _CustomerFilter.phone, Icons.phone),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Customer>>(
                stream: db.select(db.customers).watch(),
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
                    customers = customers.where((c) {
                      switch (_filter) {
                        case _CustomerFilter.name:
                          return c.shopName
                                  .toLowerCase()
                                  .contains(_searchQuery) ||
                              (c.ownerName ?? '')
                                  .toLowerCase()
                                  .contains(_searchQuery);
                        case _CustomerFilter.place:
                          return (c.place ?? '')
                              .toLowerCase()
                              .contains(_searchQuery);
                        case _CustomerFilter.phone:
                          return (c.phone ?? '')
                              .toLowerCase()
                              .contains(_searchQuery);
                        case _CustomerFilter.all:
                          return c.shopName
                                  .toLowerCase()
                                  .contains(_searchQuery) ||
                              (c.phone ?? '')
                                  .toLowerCase()
                                  .contains(_searchQuery) ||
                              (c.ownerName ?? '')
                                  .toLowerCase()
                                  .contains(_searchQuery) ||
                              (c.place ?? '')
                                  .toLowerCase()
                                  .contains(_searchQuery);
                      }
                    }).toList();
                  }

                  if (customers.isEmpty) {
                    return _buildEmptyState();
                  }

                  final groupedCustomers = <String, List<Customer>>{};
                  for (var c in customers) {
                    final place = c.place?.trim().toUpperCase() ?? '';
                    final letter = place.isNotEmpty ? place[0] : '#';
                    final key =
                        RegExp(r'[A-Z]').hasMatch(letter) ? letter : '#';
                    groupedCustomers.putIfAbsent(key, () => []).add(c);
                    if (!_letterKeys.containsKey(key)) {
                      _letterKeys[key] = GlobalKey();
                    }
                  }
                  final sortedKeys = groupedCustomers.keys.toList()..sort();

                  return Stack(
                    children: [
                      ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 40, 80),
                        itemCount: sortedKeys.length,
                        itemBuilder: (context, index) {
                          final letter = sortedKeys[index];
                          final group = groupedCustomers[letter]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            key: _letterKeys[letter],
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 16.0, bottom: 8.0, left: 4.0),
                                child: Text(letter,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.grey)),
                              ),
                              ...group.map((customer) =>
                                  _buildCustomerCard(customer, db)),
                            ],
                          );
                        },
                      ),
                      if (_searchQuery.isEmpty && sortedKeys.length > 2)
                        Positioned(
                          right: 4,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: SingleChildScrollView(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: theme.cardColor.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: sortedKeys.map((letter) {
                                    return InkWell(
                                      onTap: () {
                                        final key = _letterKeys[letter];
                                        if (key?.currentContext != null) {
                                          Scrollable.ensureVisible(
                                            key!.currentContext!,
                                            duration: const Duration(
                                                milliseconds: 300),
                                            curve: Curves.easeInOut,
                                          );
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4.0, horizontal: 4.0),
                                        child: Text(letter,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: theme.primaryColor)),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customers_fab',
        onPressed: () => _showCustomerDialog(context, db),
        icon: const Icon(Icons.add),
        label: Text('add_customer'.tr(ref)),
      ),
    );
  }

  Widget _filterChip(String label, _CustomerFilter filter, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = _filter == filter;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14, color: isSelected ? Colors.white : theme.primaryColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: isSelected ? Colors.white : null)),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = filter),
      selectedColor: theme.primaryColor,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomerCard(
        customer: customer,
        onTap: () => _navigateToNewOrder(customer),
        onNewOrder: () => _navigateToNewOrder(customer),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('deleted'.tr(ref))));
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
}
