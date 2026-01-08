import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:lottie/lottie.dart';
import '../main.dart';
import '../theme.dart';
import '../db/database.dart';
import '../services/translation_service.dart';
import '../widgets/safe_widgets.dart';
import 'new_order_screen.dart';
import '../services/excel_service.dart';
import '../providers/settings_provider.dart';

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
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search_hint'.tr(ref),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),

          // Customer List inside Expanded to take remaining space but still scrollable
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: db.select(db.customers).watch(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var customers = snapshot.data!;
                if (_searchQuery.isNotEmpty) {
                  customers = customers.where((c) {
                    final shopMatch =
                        c.shopName.toLowerCase().contains(_searchQuery);
                    final phoneMatch =
                        (c.phone ?? '').toLowerCase().contains(_searchQuery);
                    final ownerMatch = (c.ownerName ?? '')
                        .toLowerCase()
                        .contains(_searchQuery);
                    return shopMatch || phoneMatch || ownerMatch;
                  }).toList();
                }

                if (customers.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      16, 0, 16, 80), // bottom padding for FAB
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return _buildCustomerCard(customer, db);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerDialog(context, db),
        icon: const Icon(Icons.add),
        label: Text('add_customer'.tr(ref)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SafeColumn(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child:
                Lottie.asset('assets/lottie/empty.json', fit: BoxFit.contain),
          ),
          const SizedBox(height: 16),
          SafeText(
            _searchQuery.isEmpty
                ? 'no_customers'.tr(ref)
                : 'none_found'.tr(ref),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty)
            SafeText(
              'add_first'.tr(ref),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.grey),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer, AppDatabase db) {
    final theme = Theme.of(context);
    return SafeCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.cardColor,
      child: InkWell(
        onTap: () => _navigateToNewOrder(customer),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SafeRow(
            leading: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    customer.shopName.isNotEmpty
                        ? customer.shopName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SafeColumn(
                    children: [
                      SafeText(customer.shopName,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: theme.primaryColor)),
                      if (customer.place != null && customer.place!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 12, color: AppTheme.grey),
                            const SizedBox(width: 4),
                            SafeText(customer.place!,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.grey)),
                          ],
                        ),
                      if (customer.phone != null && customer.phone!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.phone,
                                size: 12, color: AppTheme.grey),
                            const SizedBox(width: 4),
                            SafeText(customer.phone!,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.grey)),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'order':
                    _navigateToNewOrder(customer);
                    break;
                  case 'edit':
                    _showCustomerDialog(context, db, customer: customer);
                    break;
                  case 'delete':
                    _confirmDelete(customer, db);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                    value: 'order',
                    child: SafeRow(
                        leading: const Icon(Icons.add_shopping_cart, size: 20),
                        trailing: Text('new_order'.tr(ref)))),
                PopupMenuItem(
                    value: 'edit',
                    child: SafeRow(
                        leading: const Icon(Icons.edit, size: 20),
                        trailing: Text('edit'.tr(ref)))),
                PopupMenuItem(
                    value: 'delete',
                    child: SafeRow(
                        leading: const Icon(Icons.delete,
                            size: 20, color: AppTheme.error),
                        trailing: Text('delete'.tr(ref),
                            style: const TextStyle(color: AppTheme.error)))),
              ],
            ),
          ),
        ),
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
      // Background consolidated backup
      await ExcelService.appendDeletedCustomer(customer,
          customPath: ref.read(settingsProvider).excelSavePath);

      await (db.delete(db.orderItems)
            ..where((tbl) => tbl.customerId.equals(customer.id)))
          .go();
      await (db.delete(db.lorryShipments)
            ..where((tbl) => tbl.customerId.equals(customer.id)))
          .go();
      await (db.delete(db.customers)
            ..where((tbl) => tbl.id.equals(customer.id)))
          .go();
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(isEditing ? 'edit_customer'.tr(ref) : 'add_customer'.tr(ref)),
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
                      prefixIcon: const Icon(Icons.phone)),
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              TextField(
                  controller: gstController,
                  decoration: const InputDecoration(
                      labelText: 'GST / TIN', prefixIcon: Icon(Icons.receipt)),
                  textCapitalization: TextCapitalization.characters),
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
                await db.into(db.customers).insert(companion.copyWith(
                    id: drift.Value(
                        DateTime.now().millisecondsSinceEpoch.toString())));
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(isEditing ? 'update'.tr(ref) : 'save'.tr(ref)),
          ),
        ],
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
