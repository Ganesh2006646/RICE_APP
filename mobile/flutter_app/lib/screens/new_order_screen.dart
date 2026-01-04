import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../theme.dart';
import '../db/database.dart';
import '../services/excel_service.dart';
import '../services/email_service.dart';
import '../services/settings_service.dart';
import '../services/translation_service.dart';
import '../services/whatsapp_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/safe_widgets.dart';

class OrderItemFormData {
  Product? product;
  int bags26;
  int bags10;
  int bags5;
  double rate; // Defined ONLY for 100 KG (1 Quintal)

  OrderItemFormData({
    this.product,
    this.bags26 = 0,
    this.bags10 = 0,
    this.bags5 = 0,
    this.rate = 0,
  });

  // WEIGHTS
  double get kg26 => bags26 * 26.0;
  double get kg10 => bags10 * 10.0;
  double get kg5 => bags5 * 5.0;
  double get kgTotal => kg26 + kg10 + kg5;
  double get qtlTotal => kgTotal / 100.0;

  // 26 KG LOGIC: No Packing, No GST, 1% AMC
  double get value26 => (rate / 100.0) * 26.0 * bags26;
  double get amc26 => value26 * 0.01;
  double get total26 => value26 + amc26;

  // 10 KG LOGIC: ₹200 Packing, 1% AMC, 5% GST
  double get baseValue10 => (rate / 100.0) * 10.0 * bags10;
  double get packing10 => 200.0 * bags10;
  double get subtotal10 => baseValue10 + packing10;
  double get amc10 => subtotal10 * 0.01;
  double get gst10 => (subtotal10 + amc10) * 0.05;
  double get total10 => subtotal10 + amc10 + gst10;

  // 5 KG LOGIC: ₹250 Packing, 1% AMC, 5% GST
  double get baseValue5 => (rate / 100.0) * 5.0 * bags5;
  double get packing5 => 250.0 * bags5;
  double get subtotal5 => baseValue5 + packing5;
  double get amc5 => subtotal5 * 0.01;
  double get gst5 => (subtotal5 + amc5) * 0.05;
  double get total5 => subtotal5 + amc5 + gst5;

  // TOTALS for Line Item
  double get netAmount => total26 + total10 + total5;
  double get amcAmount => amc26 + amc10 + amc5;
  double get gstAmount => gst10 + gst5;

  // Percentage Helpers for DB/Legacy UI
  double get amcPercent => 1.0;
  double get gstPercent {
    double taxableSubtotal = (subtotal10 + amc10) + (subtotal5 + amc5);
    if (taxableSubtotal == 0) return 0.0;
    return (gstAmount / taxableSubtotal) * 100.0;
  }

  // Display fields for UI/Excel
  double get baseAmount => value26 + baseValue10 + baseValue5;

  bool get isValid =>
      product != null && (bags26 > 0 || bags10 > 0 || bags5 > 0) && rate > 0;
}

/// Lorry Based Order Screen - Refactored for Stability
/// ZERO OVERFLOW ERRORS - AGING USER FRIENDLY
class NewOrderScreen extends ConsumerStatefulWidget {
  final Customer? preselectedCustomer;
  final String? duplicateOrderId;

  const NewOrderScreen(
      {super.key, this.preselectedCustomer, this.duplicateOrderId});

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  int _currentStep = 1;
  DateTime _loadingDate = DateTime.now();
  final TextEditingController _capacityController =
      TextEditingController(text: '110.0');
  final List<CustomerLoadFormData> _customers = [];
  bool _sendEmail = true;
  bool _isSaving = false;
  String? _orderNumber;

  @override
  void initState() {
    super.initState();
    _initLorry();
  }

  @override
  void dispose() {
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _initLorry() async {
    final db = ref.read(databaseProvider);
    final orderCount = await db.select(db.orders).get();
    final nextNum =
        await SettingsService.generateOrderNumber(orderCount.length);
    setState(() => _orderNumber = nextNum);

    if (widget.duplicateOrderId != null) {
      await _loadDuplicateData(widget.duplicateOrderId!, db);
    } else {
      _addCustomer(initial: widget.preselectedCustomer);
    }
  }

  Future<void> _loadDuplicateData(String orderId, AppDatabase db) async {
    try {
      final originalOrder = await (db.select(db.orders)
            ..where((tbl) => tbl.id.equals(orderId)))
          .getSingle();
      _capacityController.text = originalOrder.lorryCapacity.toString();

      final shipmentRows = await (db.select(db.lorryShipments).join([
        drift.innerJoin(db.customers,
            db.customers.id.equalsExp(db.lorryShipments.customerId)),
      ])
            ..where(db.lorryShipments.orderId.equals(orderId)))
          .get();

      final allItems = await (db.select(db.orderItems)
            ..where((tbl) => tbl.orderId.equals(orderId)))
          .get();
      final products = await db.select(db.products).get();

      final loadedCustomers = <CustomerLoadFormData>[];
      for (var row in shipmentRows) {
        final customer = row.readTable(db.customers);
        final myItems =
            allItems.where((i) => i.customerId == customer.id).toList();

        final formItems = myItems.map((i) {
          final product = products.firstWhere((p) => p.id == i.productId,
              orElse: () => _fallbackProduct());
          return OrderItemFormData(
            product: product,
            bags26: i.bags26,
            bags10: i.bags10,
            bags5: i.bags5,
            rate: i.ratePerQtl,
          );
        }).toList();

        if (formItems.isEmpty) formItems.add(OrderItemFormData());
        loadedCustomers
            .add(CustomerLoadFormData(customer: customer, items: formItems));
      }

      if (loadedCustomers.isNotEmpty) {
        setState(() {
          _customers.clear();
          _customers.addAll(loadedCustomers);
        });
      } else {
        _addCustomer();
      }
    } catch (e) {
      _addCustomer();
    }
  }

  Product _fallbackProduct() => Product(
      id: '?',
      name: 'Unknown',
      defaultPrice: 0,
      gstRateDefault: 0,
      unit: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now());

  void _addCustomer({Customer? initial}) {
    setState(() {
      _customers.add(CustomerLoadFormData(
          customer: initial, items: [OrderItemFormData()]));
    });
  }

  void _removeCustomer(int index) {
    if (_customers.length > 1) {
      setState(() => _customers.removeAt(index));
    }
  }

  double get _totalQtl => _customers.fold(0.0, (sum, c) => sum + c.totalQtl);
  double get _totalAmount =>
      _customers.fold(0.0, (sum, c) => sum + (c.isValid ? c.totalAmount : 0.0));
  double get _capacity => double.tryParse(_capacityController.text) ?? 110.0;

  Future<void> _saveLorryOrder() async {
    if (_customers.every((c) => !c.isValid)) {
      _showError('valid_items_required'.tr(ref));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final lorryId = DateTime.now().millisecondsSinceEpoch.toString();

      await db.transaction(() async {
        await db.into(db.orders).insert(OrdersCompanion(
              id: drift.Value(lorryId),
              loadingDate: drift.Value(_loadingDate),
              totalAmount: drift.Value(_totalAmount),
              lorryCapacity: drift.Value(_capacity),
              notes: drift.Value(_orderNumber),
              createdAt: drift.Value(DateTime.now()),
              updatedAt: drift.Value(DateTime.now()),
            ));

        for (var customerLoad in _customers) {
          if (!customerLoad.isValid) continue;
          final cId = customerLoad.customer!.id;

          await db.into(db.lorryShipments).insert(LorryShipmentsCompanion(
                id: drift.Value('${lorryId}_$cId'),
                orderId: drift.Value(lorryId),
                customerId: drift.Value(cId),
                totalAmount: drift.Value(customerLoad.totalAmount),
              ));

          for (var item in customerLoad.items) {
            if (!item.isValid) continue;
            await db.into(db.orderItems).insert(OrderItemsCompanion(
                  id: drift.Value(
                      '${lorryId}_${cId}_${item.product!.id}_${DateTime.now().microsecondsSinceEpoch}'),
                  orderId: drift.Value(lorryId),
                  customerId: drift.Value(cId),
                  productId: drift.Value(item.product!.id),
                  bags26: drift.Value(item.bags26),
                  bags10: drift.Value(item.bags10),
                  bags5: drift.Value(item.bags5),
                  qtyKg: drift.Value(item.kgTotal),
                  qtyQtl: drift.Value(item.qtlTotal),
                  ratePerQtl: drift.Value(item.rate),
                  amcAmount: drift.Value(item.amcAmount),
                  gstPercent: drift.Value(item.gstPercent),
                  gstAmount: drift.Value(item.gstAmount),
                  lineAmount: drift.Value(item.baseAmount),
                  netAmount: drift.Value(item.netAmount),
                ));
          }
        }
      });

      final validCustomers =
          _customers.where((c) => c.isValid).map((c) => c.customer!).toList();
      final allItems = await (db.select(db.orderItems)
            ..where((t) => t.orderId.equals(lorryId)))
          .get();
      final products = await db.select(db.products).get();
      final lorryOrder = await (db.select(db.orders)
            ..where((t) => t.id.equals(lorryId)))
          .getSingle();

      final excelPath = await ExcelService.generateLorryExcel(
        order: lorryOrder,
        items: allItems,
        customers: validCustomers,
        products: products,
        orderNumber: _orderNumber ?? lorryId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('saved_successfully'.tr(ref)),
            backgroundColor: AppTheme.success));

        // Show success and offering sharing options
        setState(() => _currentStep = 3); // A final success/share step?
        // For now let's just go back or stay on review with sharing buttons enabled.

        if (_sendEmail) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            final shouldShare = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('share'.tr(ref)),
                content: Text('share_with_mill_confirm'.tr(ref)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('later'.tr(ref))),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('share_now'.tr(ref))),
                ],
              ),
            );

            if (shouldShare == true && mounted) {
              await EmailService.shareOrderExcel(
                  filePath: excelPath,
                  customerName: 'multi_customer_lorry'.tr(ref),
                  orderNumber: _orderNumber ?? lorryId);
            }
          }
        }

        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showError('${'failed_to_save_order'.tr(ref)}: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.error));
  }

  void _validateAndReview() {
    // 1. Check for at least one customer
    if (_customers.isEmpty) {
      _showError('valid_items_required'.tr(ref));
      return;
    }

    for (var c in _customers) {
      // 2. Check each customer has items
      if (c.items.isEmpty) {
        _showError('${c.customer?.shopName}: Add at least one item');
        return;
      }

      for (var item in c.items) {
        // 3. Check for valid Product
        if (item.product == null) {
          _showError('Select a product for all items');
          return;
        }

        // 4. Check for Rate > 0
        if (item.rate <= 0) {
          _showError('Rate must be greater than 0');
          return;
        }

        // 5. Check for Bags > 0 (at least one type)
        if ((item.bags26 + item.bags10 + item.bags5) <= 0) {
          _showError('Enter quantity for at least one bag type');
          return;
        }
      }
    }

    setState(() => _currentStep = 2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: SafeText(
            _currentStep == 1 ? 'build_lorry'.tr(ref) : 'review_send'.tr(ref),
            style: const TextStyle(fontSize: 18)),
        actions: [
          if (_currentStep == 1)
            TextButton.icon(
              onPressed: _validateAndReview,
              icon: const Icon(Icons.arrow_forward),
              label: Text('review'.tr(ref)),
            )
          else
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveLorryOrder,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text('save_send'.tr(ref)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _currentStep == 1
          ? _buildLorryBuilder()
          : (_currentStep == 2 || _currentStep == 3
              ? _buildReviewPage()
              : null),
      bottomNavigationBar:
          _currentStep == 1 ? _buildLorryProgressFooter() : null,
    );
  }

  Widget _buildLorryBuilder() {
    final theme = Theme.of(context);
    return SafePage(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeColumn(
        children: [
          // Lorry Info Card
          SafeCard(
            color: theme.cardColor,
            child: SafeColumn(
              children: [
                SafeRow(
                  leading: Expanded(
                    child: TextFormField(
                      initialValue: _orderNumber,
                      decoration: InputDecoration(
                        labelText: 'order_no'.tr(ref),
                        prefixIcon: const Icon(Icons.tag),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => _orderNumber = v,
                    ),
                  ),
                  trailing: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                          context: context,
                          initialDate: _loadingDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030));
                      if (date != null) setState(() => _loadingDate = date);
                    },
                    child: _buildInfoItem(
                        'loading_date'.tr(ref),
                        DateFormat('dd MMM yyyy').format(_loadingDate),
                        Icons.calendar_today),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'lorry_capacity'.tr(ref),
                    prefixIcon: const Icon(Icons.balance),
                    helperText: 'lorry_capacity_helper'.tr(ref),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Customers Header
          SafeRow(
            leading: SafeText('step_2_add_customers'.tr(ref),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            trailing: TextButton.icon(
              onPressed: () => _addCustomer(),
              icon: const Icon(Icons.person_add, size: 20),
              label: Text('add_party'.tr(ref)),
            ),
          ),
          const SizedBox(height: 12),

          // Customer Cards
          ..._customers
              .asMap()
              .entries
              .map((entry) => _buildCustomerCard(entry.key, entry.value)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(int index, CustomerLoadFormData data) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);

    return SafeCard(
      padding: EdgeInsets.zero,
      color: theme.cardColor,
      child: SafeColumn(
        children: [
          SafeListTile(
            onTap: () => setState(() => data.isExpanded = !data.isExpanded),
            leading: CircleAvatar(
              backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
              radius: 16,
              child: Text('${index + 1}',
                  style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
            title: data.customer?.shopName ?? 'select_customer'.tr(ref),
            subtitle: data.customer?.place,
            trailing:
                Icon(data.isExpanded ? Icons.expand_less : Icons.expand_more),
          ),
          if (data.isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SafeColumn(
                children: [
                  if (data.customer == null)
                    StreamBuilder<List<Customer>>(
                      stream: db.select(db.customers).watch(),
                      builder: (context, snapshot) {
                        final allCustomers = snapshot.data ?? [];
                        return SearchAnchor(
                          builder: (context, controller) => SearchBar(
                            controller: controller,
                            padding: const WidgetStatePropertyAll<EdgeInsets>(
                                EdgeInsets.symmetric(horizontal: 16.0)),
                            onTap: () => controller.openView(),
                            onChanged: (_) => controller.openView(),
                            leading: const Icon(Icons.search),
                            hintText: 'search_hint'.tr(ref),
                          ),
                          suggestionsBuilder: (context, controller) {
                            final keyword = controller.text.toLowerCase();
                            final filtered = allCustomers.where((c) {
                              return c.shopName
                                      .toLowerCase()
                                      .contains(keyword) ||
                                  (c.phone ?? '')
                                      .toLowerCase()
                                      .contains(keyword);
                            }).toList();
                            return filtered.map((c) => ListTile(
                                  title: Text(c.shopName),
                                  subtitle: Text(c.place ?? ''),
                                  onTap: () => setState(() {
                                    data.customer = c;
                                    controller.closeView(null);
                                  }),
                                ));
                          },
                        );
                      },
                    ),
                  if (data.customer != null) ...[
                    SafeRow(
                      leading: SafeText('rice_varieties'.tr(ref),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      trailing: TextButton.icon(
                        onPressed: () =>
                            setState(() => data.items.add(OrderItemFormData())),
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        label: Text('add_rice'.tr(ref)),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Scrollable varieties list
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SafeColumn(
                        children: [
                          _buildTableHeader(),
                          ...data.items.asMap().entries.map((itemEntry) =>
                              _buildItemRow(
                                  data, itemEntry.key, itemEntry.value)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: SafeRow(
                        leading: SafeText('sub_total'.tr(ref).toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor)),
                        trailing: SafeWrap(
                          children: [
                            SafeText(
                                '${data.totalQtl.toStringAsFixed(2)} ${'qtl_short'.tr(ref)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            SafeText(
                                '${ref.watch(settingsProvider).currencySymbol}${data.totalAmount.toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.primaryColor)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style:
                          TextButton.styleFrom(foregroundColor: AppTheme.error),
                      onPressed: () => _removeCustomer(index),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: Text('remove_party'.tr(ref)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          _columnHeader('rice_variety'.tr(ref), 140, align: TextAlign.left),
          _columnHeader('26kg'.tr(ref), 60),
          _columnHeader('10kg'.tr(ref), 60),
          _columnHeader('5kg'.tr(ref), 60),
          _columnHeader('rate_100kg'.tr(ref), 80),
          _columnHeader('qtl'.tr(ref), 60),
          _columnHeader('amount'.tr(ref), 100, align: TextAlign.right),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _columnHeader(String label, double width,
      {TextAlign align = TextAlign.center}) {
    return SizedBox(
        width: width,
        child: Text(label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: align));
  }

  Widget _buildItemRow(
      CustomerLoadFormData data, int index, OrderItemFormData item) {
    final theme = Theme.of(context);
    final productsStream = ref
        .read(databaseProvider)
        .select(ref.read(databaseProvider).products)
        .get();

    return FutureBuilder<List<Product>>(
        future: productsStream,
        builder: (context, snapshot) {
          final list = snapshot.data ?? [];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<Product>(
                      initialValue: item.product,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none),
                      style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyLarge?.color),
                      items: list
                          .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.name,
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (val) => setState(() {
                        item.product = val;
                        item.rate = val?.defaultPrice ?? 0;
                      }),
                    ),
                  ),
                ),
                _itemInput(60, item.bags26,
                    (v) => setState(() => item.bags26 = int.tryParse(v) ?? 0)),
                _itemInput(60, item.bags10,
                    (v) => setState(() => item.bags10 = int.tryParse(v) ?? 0)),
                _itemInput(60, item.bags5,
                    (v) => setState(() => item.bags5 = int.tryParse(v) ?? 0)),
                _itemInput(80, item.rate,
                    (v) => setState(() => item.rate = double.tryParse(v) ?? 0),
                    isDouble: true),
                SizedBox(
                    width: 60,
                    child: Text(item.qtlTotal.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 100,
                    child: Text(
                        '${ref.watch(settingsProvider).currencySymbol}${item.netAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right)),
                SizedBox(
                    width: 40,
                    child: IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.red),
                        onPressed: () =>
                            setState(() => data.items.removeAt(index)))),
              ],
            ),
          );
        });
  }

  Widget _itemInput(double width, num value, Function(String) onChanged,
      {bool isDouble = false}) {
    final theme = Theme.of(context);
    final initial = value == 0
        ? ''
        : (isDouble ? value.toStringAsFixed(0) : value.toString());
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: TextField(
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
          filled: true,
          fillColor: theme.inputDecorationTheme.fillColor ?? Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppTheme.lightGrey)),
        ),
        onChanged: onChanged,
        controller: TextEditingController(text: initial)
          ..selection = TextSelection.collapsed(offset: initial.length),
      ),
    );
  }

  Widget _buildLorryProgressFooter() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: const Border(top: BorderSide(color: AppTheme.lightGrey)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SafeProgress(
            label: 'lorry_fill'.tr(ref),
            value: _totalQtl,
            max: _capacity,
            suffix: 'QTL',
            color: _totalQtl / _capacity > 0.9
                ? Colors.orange
                : theme.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewPage() {
    final theme = Theme.of(context);
    return SafePage(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeColumn(
        children: [
          SafeCard(
            color: theme.cardColor,
            child: SafeColumn(
              children: [
                _summaryRow('total_customers'.tr(ref),
                    '${_customers.where((c) => c.isValid).length}'),
                _summaryRow('total_weight'.tr(ref),
                    '${_totalQtl.toStringAsFixed(2)} QTL'),
                _summaryRow('total_value'.tr(ref),
                    '${ref.watch(settingsProvider).currencySymbol}${_totalAmount.toStringAsFixed(0)}',
                    isTotal: true),
                const Divider(height: 32),
                SwitchListTile(
                  title: Text('send_to_mill'.tr(ref)),
                  value: _sendEmail,
                  onChanged: (v) => setState(() => _sendEmail = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // WhatsApp Summary Action
          SafeCard(
            color: theme.primaryColor.withValues(alpha: 0.1),
            child: SafeColumn(
              children: [
                FilledButton.icon(
                  onPressed: _sendWhatsAppSummary,
                  icon: const Icon(Icons.chat),
                  label: Text('whatsapp_summary'.tr(ref)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 12),
                SafeText('whatsapp_summary_helper'.tr(ref),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppTheme.grey)),
              ],
            ),
          ),

          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => setState(() => _currentStep = 1),
            icon: const Icon(Icons.edit),
            label: Text('back_to_editing'.tr(ref)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _sendWhatsAppSummary() {
    try {
      final settings = ref.read(settingsProvider);
      final validCustomers = _customers
          .where((c) => c.customer != null)
          .map((c) => c.customer!)
          .toList();

      final List<OrderItem> allItems = [];
      for (var cLoad in _customers) {
        if (cLoad.customer == null) continue;
        for (var item in cLoad.items) {
          if (item.isValid) {
            allItems.add(OrderItem(
              id: '',
              orderId: '',
              productId: item.product!.id,
              customerId: cLoad.customer!.id,
              bags26: item.bags26,
              bags10: item.bags10,
              bags5: item.bags5,
              qtyKg: item.kgTotal,
              qtyQtl: item.qtlTotal,
              ratePerQtl: item.rate,
              amcAmount: item.amcAmount,
              amcPercent: item.amcPercent,
              gstPercent: item.gstPercent,
              gstAmount: item.gstAmount,
              lineAmount: item.baseAmount,
              netAmount: item.netAmount,
            ));
          }
        }
      }

      final products = <Product>[];
      for (var cLoad in _customers) {
        for (var item in cLoad.items) {
          if (item.product != null &&
              !products.any((p) => p.id == item.product!.id)) {
            products.add(item.product!);
          }
        }
      }

      final orderStub = Order(
        id: '',
        loadingDate: _loadingDate,
        totalAmount: _totalAmount,
        notes: _orderNumber,
        lorryCapacity: _capacity,
        amountPaid: 0,
        paymentStatus: 'UNPAID',
        isSynced: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        customerId: null,
      );

      WhatsAppService.sendLorrySummaryMessage(
        customers: validCustomers,
        order: orderStub,
        allItems: allItems,
        allProducts: products,
        millContactPhone: settings.millContactPhone,
        currencySymbol: settings.currencySymbol,
      );
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Widget _summaryRow(String label, String value, {bool isTotal = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SafeRow(
        leading: SafeText(label,
            style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 16 : 14)),
        trailing: SafeText(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTotal ? 16 : 14,
                color: isTotal ? theme.primaryColor : null)),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.primaryColor),
        const SizedBox(width: 8),
        SafeColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeText(label,
                style: const TextStyle(fontSize: 10, color: AppTheme.grey)),
            SafeText(value,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ],
    );
  }
}

class CustomerLoadFormData {
  Customer? customer;
  final List<OrderItemFormData> items;
  bool isExpanded;
  String paymentStatus;
  DateTime? dueDate;

  CustomerLoadFormData(
      {this.customer,
      required this.items,
      this.isExpanded = true,
      this.paymentStatus = 'UNPAID',
      this.dueDate});

  double get totalQtl =>
      items.fold(0, (sum, item) => sum + (item.isValid ? item.qtlTotal : 0));
  double get totalAmount =>
      items.fold(0, (sum, item) => sum + (item.isValid ? item.netAmount : 0));
  bool get isValid => customer != null && items.any((item) => item.isValid);
}
