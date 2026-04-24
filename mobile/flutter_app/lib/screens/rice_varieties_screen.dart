import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:lottie/lottie.dart';
import '../main.dart';
import '../theme.dart';
import '../db/database.dart';
import '../services/translation_service.dart';
import '../providers/settings_provider.dart';
import '../services/excel_service.dart';
import '../widgets/safe_widgets.dart';

/// Screen for managing rice varieties (products) with full CRUD operations
/// Renamed from ProductsScreen to better match domain terminology
class RiceVarietiesScreen extends ConsumerWidget {
  const RiceVarietiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('rice_varieties'.tr(ref)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'import_from_excel'.tr(ref),
            onPressed: () => _handleImport(context, db, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'add_rice_variety'.tr(ref),
            onPressed: () => _showProductDialog(context, db, ref),
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
            return _buildEmptyState(context, db, ref);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(context, product, db, ref);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context, db, ref),
        icon: const Icon(Icons.add),
        label: Text('add_rice'.tr(ref)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppDatabase db, WidgetRef ref) {
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
            'no_rice_varieties'.tr(ref),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.grey,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'add_rice_helper'.tr(ref),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.grey,
                ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => _showProductDialog(context, db, ref),
                icon: const Icon(Icons.add),
                label: Text('add_first_variety'.tr(ref)),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _handleImport(context, db, ref),
                icon: const Icon(Icons.file_upload_outlined),
                label: Text('import_excel'.tr(ref)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleImport(
      BuildContext context, AppDatabase db, WidgetRef ref) async {
    final result = await ExcelService.importProductsFromExcel(db);
    if (context.mounted) {
      SafeSnackBar.show(context, result['message'],
          isError: !result['success']);
    }
  }

  Widget _buildProductCard(
      BuildContext context, Product product, AppDatabase db, WidgetRef ref) {
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
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.grass,
                color: Theme.of(context).primaryColor,
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
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${ref.watch(settingsProvider).currencySymbol}${product.defaultPrice.toStringAsFixed(0)} / ${'qtl_short'.tr(ref)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
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
                    _showProductDialog(context, db, ref, product: product);
                    break;
                  case 'delete':
                    _confirmDelete(context, product, db, ref);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 20),
                      const SizedBox(width: 12),
                      Text('edit'.tr(ref)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 20, color: AppTheme.error),
                      const SizedBox(width: 12),
                      Text('delete'.tr(ref),
                          style: const TextStyle(color: AppTheme.error)),
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
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${'delete'.tr(ref)}?'),
        content: Text('delete_variety_confirm'.tr(ref)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr(ref)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('delete'.tr(ref)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Background consolidated backup
      await ExcelService.appendDeletedVariety(product,
          customPath: ref.read(settingsProvider).excelSavePath);

      await (db.delete(db.products)..where((tbl) => tbl.id.equals(product.id)))
          .go();

      if (context.mounted) {
        SafeSnackBar.show(context, 'rice_variety_deleted'.tr(ref));
      }
    }
  }

  void _showProductDialog(BuildContext context, AppDatabase db, WidgetRef ref,
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
          title: Text(isEditing
              ? 'edit_rice_variety'.tr(ref)
              : 'add_rice_variety'.tr(ref)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '${'variety_name'.tr(ref)} *',
                    prefixIcon: const Icon(Icons.grass),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: skuController,
                  decoration: InputDecoration(
                    labelText: '${'short_code'.tr(ref)} (Optional)',
                    hintText: 'e.g., SMO-001',
                    prefixIcon: const Icon(Icons.qr_code),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText:
                        '${'rate'.tr(ref)}/${'qtl_short'.tr(ref)} (${ref.watch(settingsProvider).currencySymbol}) *',
                    prefixIcon: const Icon(Icons.currency_rupee),
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
                    title: const Text('GST 5%'),
                    subtitle: Text(
                      isGst5 ? 'branded_rice'.tr(ref) : 'loose_rice'.tr(ref),
                      style: TextStyle(
                        color: isGst5 ? Colors.orange.shade700 : AppTheme.grey,
                        fontSize: 12,
                      ),
                    ),
                    value: isGst5,
                    activeThumbColor: Theme.of(context).primaryColor,
                    onChanged: (val) => setState(() => isGst5 = val),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'gst_note'.tr(ref),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.grey,
                        fontStyle: FontStyle.italic,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Note: 5% GST applies only to 5kg & 10kg bags. 26kg bags are always tax-free.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade800,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr(ref)),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  SafeSnackBar.show(context, 'name_required'.tr(ref),
                      isError: true);
                  return;
                }

                final price = double.tryParse(priceController.text.trim());
                if (price == null || price <= 0) {
                  SafeSnackBar.show(context, 'valid_price_required'.tr(ref),
                      isError: true);
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
                        id: drift.Value(generateId()),
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
                  SafeSnackBar.show(
                      context,
                      isEditing
                          ? 'variety_updated'.tr(ref)
                          : 'variety_added'.tr(ref));
                  Navigator.pop(context);
                }
              },
              child: Text(isEditing ? 'update'.tr(ref) : 'save'.tr(ref)),
            ),
          ],
        ),
      ),
    );
  }
}
