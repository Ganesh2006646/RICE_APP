import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../main.dart';
import '../theme.dart';
import '../db/database.dart';
import '../services/translation_service.dart';
import '../providers/settings_provider.dart';
import '../services/excel_service.dart';
import '../widgets/safe_widgets.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/variety_card.dart';

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
      body: SafePage(
        padding: EdgeInsets.zero,
        child: StreamBuilder<List<Product>>(
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
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return _buildProductCard(context, product, db, ref);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'rice_varieties_fab',
        onPressed: () => _showProductDialog(context, db, ref),
        icon: const Icon(Icons.add),
        label: Text('add_rice'.tr(ref)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppDatabase db, WidgetRef ref) {
    return EmptyStateWidget(
      icon: Icons.grass_outlined,
      title: 'no_rice_varieties'.tr(ref),
      description: 'add_rice_helper'.tr(ref),
      actionLabel: 'add_first_variety'.tr(ref),
      onAction: () => _showProductDialog(context, db, ref),
    );
  }

  Future<void> _handleImport(
      BuildContext context, AppDatabase db, WidgetRef ref) async {
    // ── STEP 1: dry-run to build preview ────────────────────────────────────
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Reading price list…'),
              ],
            ),
          ),
        ),
      ),
    );

    final preview =
        await ExcelService.importDailyPriceListFromExcel(db, dryRun: true);

    if (!context.mounted) return;
    Navigator.pop(context); // close loading spinner

    final success = preview['success'] as bool? ?? false;
    if (!success) {
      SafeSnackBar.show(
        context,
        preview['message'] as String? ?? 'Import failed',
        isError: true,
      );
      return;
    }

    // ── STEP 2: show review sheet; only commit if user confirms ──────────────
    await _showReviewSheet(context, db, preview, ref);
  }

  /// Shows a bottom sheet listing every proposed price change.
  /// Tapping "Apply" triggers the real DB commit; "Cancel" discards everything.
  Future<void> _showReviewSheet(BuildContext context, AppDatabase db,
      Map<String, dynamic> preview, WidgetRef ref) async {
    final previewList =
        (preview['preview'] as List?)?.cast<PriceChangePreview>() ?? [];
    final notFound = (preview['notFound'] as List?)?.cast<String>() ?? [];
    final willUpdate = preview['updated'] as int? ?? 0;

    if (willUpdate == 0 && notFound.isEmpty) {
      SafeSnackBar.show(context,
          'Nothing to update — all prices already match your database.');
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ReviewBottomSheet(
        previewList: previewList,
        notFound: notFound,
        willUpdate: willUpdate,
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // ── STEP 3: commit ───────────────────────────────────────────────────────
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Applying price updates…'),
              ],
            ),
          ),
        ),
      ),
    );

    final result =
        await ExcelService.importDailyPriceListFromExcel(db, dryRun: false);

    if (!context.mounted) return;
    Navigator.pop(context); // close commit spinner

    final commitSuccess = result['success'] as bool? ?? false;
    if (!commitSuccess) {
      SafeSnackBar.show(
          context, result['message'] as String? ?? 'Commit failed',
          isError: true);
      return;
    }

    _showImportResultDialog(context, result, ref);
  }

  void _showImportResultDialog(
      BuildContext context, Map<String, dynamic> result, WidgetRef ref) {
    final updated = result['updated'] as int? ?? 0;
    final notFound = (result['notFound'] as List?)?.cast<String>() ?? [];
    final zeroPriced = (result['zeroPriced'] as List?)?.cast<String>() ?? [];
    final errors = (result['errors'] as List?)?.cast<String>() ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Row(
          children: [
            Icon(
              updated > 0 ? Icons.check_circle : Icons.warning_amber_rounded,
              color: updated > 0 ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                updated > 0 ? 'Price Update Complete' : 'Nothing Updated',
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Updated section
              if (updated > 0) ...[
                _resultChip(
                  context,
                  '✅  $updated ${updated == 1 ? 'variety' : 'varieties'} updated',
                  Colors.green,
                ),
                const SizedBox(height: 12),
              ],

              // ⚠️ Not found section
              if (notFound.isNotEmpty) ...[
                _resultChip(
                  context,
                  '⚠️  ${notFound.length} not found in your database',
                  Colors.orange,
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: notFound.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.fiber_manual_record,
                              size: 8, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              notFound[i],
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap "+" to add these varieties manually, then re-import.',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                ),
                const SizedBox(height: 12),
              ],

              // ⏭ Zero-price skipped
              if (zeroPriced.isNotEmpty) ...[
                _resultChip(
                  context,
                  '⏭  ${zeroPriced.length} skipped (price = 0)',
                  Colors.grey,
                ),
                const SizedBox(height: 4),
                Text(
                  zeroPriced.take(5).join(', ') +
                      (zeroPriced.length > 5 ? '…' : ''),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),
              ],

              // ❌ Errors
              if (errors.isNotEmpty) ...[
                _resultChip(context, '❌  ${errors.length} errors', Colors.red),
                const SizedBox(height: 4),
                Text(
                  errors.join('\n'),
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                ),
              ],

              // All good message
              if (updated > 0 && notFound.isEmpty && errors.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'All varieties in the price sheet were matched and updated successfully.',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _resultChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
      ),
    );
  }

  Widget _buildProductCard(
      BuildContext context, Product product, AppDatabase db, WidgetRef ref) {
    return VarietyCard(
      product: product,
      currencySymbol: ref.watch(settingsProvider).currencySymbol,
      onEdit: () => _showProductDialog(context, db, ref, product: product),
      onDelete: () => _confirmDelete(context, product, db, ref),
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
        scrollable: true,
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
      try {
        final usageRows = await (db.select(db.orderItems)
              ..where((tbl) => tbl.productId.equals(product.id)))
            .get();
        if (usageRows.isNotEmpty) {
          if (context.mounted) {
            SafeSnackBar.show(
              context,
              'Cannot delete this variety because it is used in existing orders.',
              isError: true,
            );
          }
          return;
        }

        // Background consolidated backup
        await ExcelService.appendDeletedVariety(product,
            customPath: ref.read(settingsProvider).excelSavePath);

        await (db.delete(db.products)
              ..where((tbl) => tbl.id.equals(product.id)))
            .go();

        if (context.mounted) {
          SafeSnackBar.show(context, 'rice_variety_deleted'.tr(ref));
        }
      } catch (e) {
        if (context.mounted) {
          SafeSnackBar.show(context, '${'failed_to_delete'.tr(ref)}: $e',
              isError: true);
        }
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
    bool isGalaxy = product?.isGalaxy ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
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
                    title: Row(
                      children: [
                        Icon(Icons.discount,
                            size: 18, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text('Eligible for Discount'),
                      ],
                    ),
                    subtitle: Text(
                      isGalaxy
                          ? 'Bulk discount will apply'
                          : 'Excluded from bulk discount',
                      style: TextStyle(
                        color:
                            isGalaxy ? Colors.green.shade700 : AppTheme.error,
                        fontSize: 12,
                      ),
                    ),
                    value: isGalaxy,
                    activeTrackColor: Colors.green.shade200,
                    activeThumbColor: Colors.green.shade700,
                    onChanged: (val) => setState(() => isGalaxy = val),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                    isGalaxy: drift.Value(isGalaxy),
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
                        isGalaxy: drift.Value(isGalaxy),
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

// ────────────────────────────────────────────────────────────────────────────
// Review Bottom Sheet
// ────────────────────────────────────────────────────────────────────────────

/// Bottom sheet that shows a "Review Changes" list before committing.
class _ReviewBottomSheet extends StatelessWidget {
  final List<PriceChangePreview> previewList;
  final List<String> notFound;
  final int willUpdate;

  const _ReviewBottomSheet({
    required this.previewList,
    required this.notFound,
    required this.willUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final matched = previewList.where((p) => p.isMatched).toList();
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // ── Handle ──
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.preview_outlined, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Review Price Changes',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$willUpdate to update',
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── List ──
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (matched.isNotEmpty)
                  ...matched.map((p) => _PriceChangeTile(p)),

                if (notFound.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '⚠️ ${notFound.length} not found in your database — add manually then re-import',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade700),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...notFound.take(10).map((name) => Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.fiber_manual_record,
                                size: 7, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(name,
                                    style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      )),
                  if (notFound.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Text('+ ${notFound.length - 10} more…',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ),
                ],

                const SizedBox(height: 80), // space for buttons
              ],
            ),
          ),

          // ── Action buttons ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: willUpdate > 0
                          ? () => Navigator.pop(context, true)
                          : null,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text('Apply $willUpdate Updates'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single row in the review sheet showing old → new price with colour coding.
class _PriceChangeTile extends StatelessWidget {
  final PriceChangePreview preview;
  const _PriceChangeTile(this.preview);

  @override
  Widget build(BuildContext context) {
    final dir = preview.priceDirection;
    final arrowColor = dir > 0
        ? Colors.red.shade600 // price up → red (costs more)
        : dir < 0
            ? Colors.green.shade600 // price down → green (cheaper)
            : Colors.grey;
    final arrowIcon = dir > 0
        ? Icons.arrow_upward
        : dir < 0
            ? Icons.arrow_downward
            : Icons.remove;

    final gstLabel = (preview.newGst ?? 0) > 0 ? 'GST 5%' : 'GST 0%';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(arrowIcon, size: 18, color: arrowColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview.dbName ?? preview.excelName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  if (preview.dbName != null &&
                      preview.dbName != preview.excelName)
                    Text(
                      'Excel: ${preview.excelName}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  Text(
                    gstLabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: (preview.newGst ?? 0) > 0
                            ? Colors.orange.shade700
                            : Colors.grey),
                  ),
                ],
              ),
            ),
            Text(
              preview.priceDelta,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: arrowColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
