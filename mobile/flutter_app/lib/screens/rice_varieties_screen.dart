import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:lottie/lottie.dart';
import '../main.dart';
import '../theme.dart';
import '../db/database.dart';

/// Screen for managing rice varieties (products) with full CRUD operations
/// Renamed from ProductsScreen to better match domain terminology
class RiceVarietiesScreen extends ConsumerWidget {
  const RiceVarietiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rice Varieties'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Rice Variety',
            onPressed: () => _showProductDialog(context, db),
          ),
        ],
      ),
      body: StreamBuilder<List<Product>>(
        stream: db.select(db.products).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data!;
          if (products.isEmpty) {
            return _buildEmptyState(context, db);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(context, product, db);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context, db),
        icon: const Icon(Icons.add),
        label: const Text('Add Variety'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppDatabase db) {
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
            'No rice varieties yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.darkGrey,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add rice varieties to use in orders',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.grey,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showProductDialog(context, db),
            icon: const Icon(Icons.add),
            label: const Text('Add First Variety'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
      BuildContext context, Product product, AppDatabase db) {
    final hasGst = product.gstRateDefault > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Rice Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.paleGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.grass,
                color: AppTheme.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '₹${product.defaultPrice.toStringAsFixed(0)}/QTL',
                          style: const TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: hasGst
                              ? Colors.orange.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          hasGst ? 'GST 5%' : 'GST 0%',
                          style: TextStyle(
                            color:
                                hasGst ? Colors.orange.shade700 : AppTheme.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (product.sku != null && product.sku!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'SKU: ${product.sku}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.grey,
                          ),
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showProductDialog(context, db, product: product);
                    break;
                  case 'delete':
                    _confirmDelete(context, product, db);
                    break;
                }
              },
              itemBuilder: (context) => [
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
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Product product,
    AppDatabase db,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rice Variety?'),
        content: Text(
          'Are you sure you want to delete "${product.name}"? '
          'This may affect existing orders.',
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
      await (db.delete(db.products)..where((tbl) => tbl.id.equals(product.id)))
          .go();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rice variety deleted')),
        );
      }
    }
  }

  void _showProductDialog(BuildContext context, AppDatabase db,
      {Product? product}) {
    final isEditing = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final skuController = TextEditingController(text: product?.sku ?? '');
    final priceController = TextEditingController(
      text: product != null ? product.defaultPrice.toStringAsFixed(0) : '',
    );
    bool isGst5 = product?.gstRateDefault == 5.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? 'Edit Rice Variety' : 'Add Rice Variety'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    hintText: 'e.g., Sona Masoori Old',
                    prefixIcon: Icon(Icons.grass),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: skuController,
                  decoration: const InputDecoration(
                    labelText: 'SKU (Optional)',
                    hintText: 'e.g., SMO-001',
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Rate per Quintal (₹) *',
                    hintText: 'e.g., 2200',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: const Text('Default GST Rate'),
                    subtitle: Text(
                      isGst5
                          ? 'GST 5% (for branded/packed rice)'
                          : 'GST 0% (for loose rice)',
                      style: TextStyle(
                        color: isGst5 ? Colors.orange.shade700 : AppTheme.grey,
                        fontSize: 12,
                      ),
                    ),
                    value: isGst5,
                    activeThumbColor: AppTheme.primaryGreen,
                    onChanged: (val) => setState(() => isGst5 = val),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Note: GST will be 5% if 5kg or 10kg bags are used, regardless of this setting.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.grey,
                        fontStyle: FontStyle.italic,
                      ),
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
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name is required')),
                  );
                  return;
                }

                final price = double.tryParse(priceController.text.trim());
                if (price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid price')),
                  );
                  return;
                }

                if (isEditing) {
                  await (db.update(db.products)
                        ..where((tbl) => tbl.id.equals(product.id)))
                      .write(ProductsCompanion(
                    name: drift.Value(nameController.text.trim()),
                    sku: drift.Value(skuController.text.trim().isEmpty
                        ? null
                        : skuController.text.trim()),
                    defaultPrice: drift.Value(price),
                    gstRateDefault: drift.Value(isGst5 ? 5.0 : 0.0),
                    updatedAt: drift.Value(DateTime.now()),
                  ));
                } else {
                  await db.into(db.products).insert(ProductsCompanion(
                        id: drift.Value(
                            DateTime.now().millisecondsSinceEpoch.toString()),
                        name: drift.Value(nameController.text.trim()),
                        sku: drift.Value(skuController.text.trim().isEmpty
                            ? null
                            : skuController.text.trim()),
                        defaultPrice: drift.Value(price),
                        gstRateDefault: drift.Value(isGst5 ? 5.0 : 0.0),
                        updatedAt: drift.Value(DateTime.now()),
                      ));
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          isEditing ? 'Variety updated!' : 'Variety added!'),
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
      ),
    );
  }
}
