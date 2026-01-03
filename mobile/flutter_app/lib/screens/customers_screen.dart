import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:lottie/lottie.dart';
import '../main.dart';
import '../theme.dart';
import '../db/database.dart';
import 'new_order_screen.dart';

/// Screen for managing customers with full CRUD operations
/// Includes search, edit, delete, and tap-to-create-order functionality
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
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Customer',
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

          // Customer List
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: db.select(db.customers).watch(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter customers based on search
                var customers = snapshot.data!;
                if (_searchQuery.isNotEmpty) {
                  customers = customers.where((c) {
                    final shopMatch =
                        c.shopName.toLowerCase().contains(_searchQuery);
                    final phoneMatch =
                        c.phone?.toLowerCase().contains(_searchQuery) ?? false;
                    final ownerMatch =
                        c.ownerName?.toLowerCase().contains(_searchQuery) ??
                            false;
                    return shopMatch || phoneMatch || ownerMatch;
                  }).toList();
                }

                if (customers.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
            _searchQuery.isEmpty ? 'No customers yet' : 'No customers found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.darkGrey,
                ),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty)
            Text(
              'Add your first customer to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.grey,
                  ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer, AppDatabase db) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToNewOrder(customer),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.paleGreen,
                child: Text(
                  customer.shopName[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.shopName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (customer.ownerName != null &&
                        customer.ownerName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        customer.ownerName!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.darkGrey,
                            ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (customer.place != null &&
                            customer.place!.isNotEmpty) ...[
                          const Icon(Icons.location_on,
                              size: 14, color: AppTheme.grey),
                          const SizedBox(width: 4),
                          Text(
                            customer.place!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (customer.phone != null &&
                            customer.phone!.isNotEmpty) ...[
                          const Icon(Icons.phone,
                              size: 14, color: AppTheme.grey),
                          const SizedBox(width: 4),
                          Text(
                            customer.phone!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Actions Menu
              PopupMenuButton<String>(
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
                    child: Row(
                      children: [
                        Icon(Icons.add_shopping_cart, size: 20),
                        SizedBox(width: 12),
                        Text('Create Order'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: AppTheme.error),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: AppTheme.error)),
                      ],
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

  void _navigateToNewOrder(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewOrderScreen(preselectedCustomer: customer),
      ),
    );
  }

  Future<void> _confirmDelete(Customer customer, AppDatabase db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text(
          'Are you sure you want to delete "${customer.shopName}"? '
          'This will also delete all orders associated with this customer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Delete associated orders first
      await (db.delete(db.orderItems)
            ..where((tbl) => tbl.orderId.isInQuery(
                  db.selectOnly(db.orders)
                    ..addColumns([db.orders.id])
                    ..where(db.orders.customerId.equals(customer.id)),
                )))
          .go();
      await (db.delete(db.orders)
            ..where((tbl) => tbl.customerId.equals(customer.id)))
          .go();
      await (db.delete(db.customers)
            ..where((tbl) => tbl.id.equals(customer.id)))
          .go();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer deleted')),
        );
      }
    }
  }

  void _showCustomerDialog(BuildContext context, AppDatabase db,
      {Customer? customer}) {
    final isEditing = customer != null;
    final shopNameController =
        TextEditingController(text: customer?.shopName ?? '');
    final ownerNameController =
        TextEditingController(text: customer?.ownerName ?? '');
    final placeController = TextEditingController(text: customer?.place ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final gstController = TextEditingController(text: customer?.tinGst ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final notesController = TextEditingController(text: customer?.notes ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Customer' : 'Add Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: shopNameController,
                decoration: const InputDecoration(
                  labelText: 'Shop Name *',
                  prefixIcon: Icon(Icons.store),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ownerNameController,
                decoration: const InputDecoration(
                  labelText: 'Owner Name',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: placeController,
                decoration: const InputDecoration(
                  labelText: 'Place',
                  prefixIcon: Icon(Icons.location_on),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gstController,
                decoration: const InputDecoration(
                  labelText: 'GST / TIN',
                  prefixIcon: Icon(Icons.receipt),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (shopNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Shop name is required')),
                );
                return;
              }

              if (isEditing) {
                // Update existing customer
                await (db.update(db.customers)
                      ..where((tbl) => tbl.id.equals(customer.id)))
                    .write(CustomersCompanion(
                  shopName: drift.Value(shopNameController.text.trim()),
                  ownerName: drift.Value(ownerNameController.text.trim()),
                  place: drift.Value(placeController.text.trim()),
                  phone: drift.Value(phoneController.text.trim()),
                  tinGst: drift.Value(gstController.text.trim()),
                  email: drift.Value(emailController.text.trim()),
                  notes: drift.Value(notesController.text.trim()),
                  updatedAt: drift.Value(DateTime.now()),
                ));
              } else {
                // Insert new customer
                await db.into(db.customers).insert(CustomersCompanion(
                      id: drift.Value(
                          DateTime.now().millisecondsSinceEpoch.toString()),
                      shopName: drift.Value(shopNameController.text.trim()),
                      ownerName: drift.Value(ownerNameController.text.trim()),
                      place: drift.Value(placeController.text.trim()),
                      phone: drift.Value(phoneController.text.trim()),
                      tinGst: drift.Value(gstController.text.trim()),
                      email: drift.Value(emailController.text.trim()),
                      notes: drift.Value(notesController.text.trim()),
                      updatedAt: drift.Value(DateTime.now()),
                    ));
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        isEditing ? 'Customer updated!' : 'Customer added!'),
                    backgroundColor: AppTheme.success,
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: Text(isEditing ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }
}
