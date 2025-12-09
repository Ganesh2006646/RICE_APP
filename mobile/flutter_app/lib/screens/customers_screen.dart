import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../main.dart';
import '../db/database.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(context, db),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Customer>>(
        stream: db.select(db.customers).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final customers = snapshot.data!;
          if (customers.isEmpty)
            return const Center(child: Text('No customers yet'));

          return ListView.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return ListTile(
                title: Text(customer.shopName),
                subtitle: Text(
                    '${customer.ownerName ?? ''} - ${customer.place ?? ''}'),
                leading: CircleAvatar(child: Text(customer.shopName[0])),
                onTap: () {
                  // Edit or view details
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, AppDatabase db) {
    final shopNameController = TextEditingController();
    final ownerNameController = TextEditingController();
    final placeController = TextEditingController();
    final phoneController = TextEditingController();
    final gstController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: shopNameController,
                  decoration: const InputDecoration(labelText: 'Shop Name *')),
              TextField(
                  controller: ownerNameController,
                  decoration: const InputDecoration(labelText: 'Owner Name')),
              TextField(
                  controller: placeController,
                  decoration: const InputDecoration(labelText: 'Place')),
              TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone')),
              TextField(
                  controller: gstController,
                  decoration: const InputDecoration(labelText: 'TIN/GST')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (shopNameController.text.isEmpty) return;
              db.into(db.customers).insert(CustomersCompanion(
                    id: drift.Value(
                        DateTime.now().millisecondsSinceEpoch.toString()),
                    shopName: drift.Value(shopNameController.text),
                    ownerName: drift.Value(ownerNameController.text),
                    place: drift.Value(placeController.text),
                    phone: drift.Value(phoneController.text),
                    tinGst: drift.Value(gstController.text),
                    updatedAt: drift.Value(DateTime.now()),
                  ));
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
