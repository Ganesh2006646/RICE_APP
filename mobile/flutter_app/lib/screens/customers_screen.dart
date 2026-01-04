import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:lottie/lottie.dart';
import '../main.dart';
import '../theme.dart';
import '../db/database.dart';
import '../widgets/safe_widgets.dart';
import 'new_order_screen.dart';

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

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const SafeText('Customers', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Customer',
            onPressed: () => _showCustomerDialog(context, db),
          ),
        ],
      ),
      body: SafeColumn(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by shop name or phone...',
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
        label: const Text('Add Customer'),
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
            _searchQuery.isEmpty ? 'No customers yet' : 'No customers found',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.darkGrey),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty)
            SafeText(
              'Add your first customer to get started',
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
    return SafeCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToNewOrder(customer),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SafeRow(
            leading: SafeRow(
              leading: SafeRow(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.paleGreen,
                  child: Text(
                    customer.shopName.isNotEmpty
                        ? customer.shopName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
                trailing: SafeColumn(
                  children: [
                    SafeText(customer.shopName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    if (customer.place != null && customer.place!.isNotEmpty)
                      SafeRow(
                        leading: const Icon(Icons.location_on,
                            size: 12, color: AppTheme.grey),
                        trailing: SafeText(customer.place!,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.grey)),
                      ),
                    if (customer.phone != null && customer.phone!.isNotEmpty)
                      SafeRow(
                        leading: const Icon(Icons.phone,
                            size: 12, color: AppTheme.grey),
                        trailing: SafeText(customer.phone!,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.grey)),
                      ),
                  ],
                ),
              ),
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
                const PopupMenuItem(
                    value: 'order',
                    child: SafeRow(
                        leading: Icon(Icons.add_shopping_cart, size: 20),
                        trailing: Text('Create Order'))),
                const PopupMenuItem(
                    value: 'edit',
                    child: SafeRow(
                        leading: Icon(Icons.edit, size: 20),
                        trailing: Text('Edit'))),
                const PopupMenuItem(
                    value: 'delete',
                    child: SafeRow(
                        leading:
                            Icon(Icons.delete, size: 20, color: AppTheme.error),
                        trailing: Text('Delete',
                            style: TextStyle(color: AppTheme.error)))),
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
        title: const Text('Delete Customer?'),
        content:
            Text('Are you sure you want to delete "${customer.shopName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await (db.delete(db.orderItems)
            ..where((tbl) => tbl.customerId.equals(customer.id)))
          .go();
      await (db.delete(db.lorryShipments)
            ..where((tbl) => tbl.customerId.equals(customer.id)))
          .go();
      await (db.delete(db.customers)
            ..where((tbl) => tbl.id.equals(customer.id)))
          .go();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Customer deleted')));
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
        title: Text(isEditing ? 'Edit Customer' : 'Add Customer'),
        content: SingleChildScrollView(
          child: SafeColumn(
            children: [
              TextField(
                  controller: shopNameController,
                  decoration: const InputDecoration(
                      labelText: 'Shop Name *', prefixIcon: Icon(Icons.store)),
                  textCapitalization: TextCapitalization.words),
              const SizedBox(height: 12),
              TextField(
                  controller: placeController,
                  decoration: const InputDecoration(
                      labelText: 'Place', prefixIcon: Icon(Icons.location_on)),
                  textCapitalization: TextCapitalization.words),
              const SizedBox(height: 12),
              TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                      labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
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
              child: const Text('Cancel')),
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
            child: Text(isEditing ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }
}
