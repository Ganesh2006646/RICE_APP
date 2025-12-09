import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../main.dart';
import '../db/database.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProductDialog(context, db),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Product>>(
        stream: db.select(db.products).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final products = snapshot.data!;
          if (products.isEmpty)
            return const Center(child: Text('No products yet'));

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Text(
                    'SKU: ${product.sku ?? '-'} | GST: ${product.gstRateDefault}%'),
                trailing:
                    Text('₹${product.defaultPrice.toStringAsFixed(2)}/QTL'),
                onTap: () {},
              );
            },
          );
        },
      ),
    );
  }

  void _showAddProductDialog(BuildContext context, AppDatabase db) {
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final priceController = TextEditingController();
    bool isGst5 = false; // Toggle for 0 or 5

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name *')),
              TextField(
                  controller: skuController,
                  decoration: const InputDecoration(labelText: 'SKU')),
              TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                      labelText: 'Rate per Quintal (₹) *'),
                  keyboardType: TextInputType.number),
              SwitchListTile(
                title: const Text('Apply 5% GST?'),
                subtitle: Text(isGst5 ? 'Yes (5%)' : 'No (0%)'),
                value: isGst5,
                onChanged: (val) => setState(() => isGst5 = val),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty || priceController.text.isEmpty)
                  return;
                db.into(db.products).insert(ProductsCompanion(
                      id: drift.Value(
                          DateTime.now().millisecondsSinceEpoch.toString()),
                      name: drift.Value(nameController.text),
                      sku: drift.Value(skuController.text.isEmpty
                          ? null
                          : skuController.text),
                      defaultPrice: drift.Value(
                          double.tryParse(priceController.text) ?? 0.0),
                      gstRateDefault: drift.Value(isGst5 ? 5.0 : 0.0),
                      updatedAt: drift.Value(DateTime.now()),
                    ));
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
