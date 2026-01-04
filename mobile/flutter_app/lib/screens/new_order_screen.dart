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
import '../widgets/safe_widgets.dart';

/// Data class for order item in the form
class OrderItemFormData {
  Product? product;
  int bags26;
  int bags10;
  int bags5;
  double rate;

  OrderItemFormData({
    this.product,
    this.bags26 = 0,
    this.bags10 = 0,
    this.bags5 = 0,
    this.rate = 0,
  });

  double get kgTotal => (bags26 * 26.0) + (bags10 * 10.0) + (bags5 * 5.0);
  double get qtlTotal => kgTotal / 100.0;
  double get baseAmount => qtlTotal * rate;
  double get amcPercent => 1.0;
  double get amcAmount => baseAmount * (amcPercent / 100);

  double get gstPercent {
    if (bags10 > 0 || bags5 > 0) return 5.0;
    return product?.gstRateDefault ?? 0.0;
  }

  double get gstAmount => (baseAmount + amcAmount) * (gstPercent / 100);
  double get netAmount => baseAmount + amcAmount + gstAmount;

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
      TextEditingController(text: '210.0');
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

  double get _totalQtl => _customers.fold(0, (sum, c) => sum + c.totalQtl);
  double get _totalAmount =>
      _customers.fold(0, (sum, c) => sum + c.totalAmount);
  double get _capacity => double.tryParse(_capacityController.text) ?? 210.0;

  Future<void> _saveLorryOrder() async {
    if (_customers.every((c) => !c.isValid)) {
      _showError('Please add at least one customer with valid items');
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Lorry Order saved successfully!'),
            backgroundColor: AppTheme.success));
        Navigator.pop(context);

        if (_sendEmail) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (context.mounted) {
            final shouldShare = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Share Order'),
                content: const Text(
                    'Would you like to share this order with the mill now?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Later')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Share Now')),
                ],
              ),
            );

            if (shouldShare == true && context.mounted) {
              await EmailService.shareOrderExcel(
                  filePath: excelPath,
                  customerName: "Multi-Customer Lorry",
                  orderNumber: _orderNumber ?? lorryId);
            }
          }
        }
      }
    } catch (e) {
      _showError('Failed to save order: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.error));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: SafeText(
            _currentStep == 1 ? 'Build Lorry Load' : 'Review & Send',
            style: const TextStyle(fontSize: 18)),
        actions: [
          if (_currentStep == 1)
            TextButton.icon(
              onPressed: () => setState(() => _currentStep = 2),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Review'),
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
              label: const Text('Save & Send'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _currentStep == 1 ? _buildLorryBuilder() : _buildReviewPage(),
      bottomNavigationBar:
          _currentStep == 1 ? _buildLorryProgressFooter() : null,
    );
  }

  Widget _buildLorryBuilder() {
    return SafePage(
      backgroundColor: AppTheme.offWhite,
      child: SafeColumn(
        children: [
          // Lorry Info Card
          SafeCard(
            child: SafeColumn(
              children: [
                SafeRow(
                  leading: _buildInfoItem(
                      'Order #', _orderNumber ?? '...', Icons.tag),
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
                        'Loading Date',
                        DateFormat('dd MMM yyyy').format(_loadingDate),
                        Icons.calendar_today),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Lorry Capacity (QTL)',
                    prefixIcon: Icon(Icons.balance),
                    helperText: 'Used to calculate fill progress',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Customers Header
          SafeRow(
            leading: const Text('Step 2: Add Customers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            trailing: TextButton.icon(
              onPressed: () => _addCustomer(),
              icon: const Icon(Icons.person_add, size: 20),
              label: const Text('Add Party'),
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

    return SafeCard(
      padding: EdgeInsets.zero,
      child: SafeColumn(
        children: [
          SafeListTile(
            onTap: () => setState(() => data.isExpanded = !data.isExpanded),
            leading: CircleAvatar(
              backgroundColor: AppTheme.paleGreen,
              radius: 16,
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
            title: data.customer?.shopName ?? 'Select Customer',
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
                            hintText: 'Search Shop or Phone...',
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
                      leading: const Text('Rice Varieties',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      trailing: TextButton.icon(
                        onPressed: () =>
                            setState(() => data.items.add(OrderItemFormData())),
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        label: const Text('Add Rice'),
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
                          color: AppTheme.paleGreen,
                          borderRadius: BorderRadius.circular(8)),
                      child: SafeRow(
                        leading: const Text('SUB-TOTAL',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen)),
                        trailing: SafeWrap(
                          children: [
                            Text('${data.totalQtl.toStringAsFixed(2)} QTL',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Text('₹${data.totalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGreen)),
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
                      label: const Text('Remove Party'),
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
          color: AppTheme.lightGrey, borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          _columnHeader('Rice Variety', 140, align: TextAlign.left),
          _columnHeader('26kg', 60),
          _columnHeader('10kg', 60),
          _columnHeader('5kg', 60),
          _columnHeader('Rate', 80),
          _columnHeader('QTL', 60),
          _columnHeader('Amount', 100, align: TextAlign.right),
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
    final products = ref
        .read(databaseProvider)
        .select(ref.read(databaseProvider).products)
        .get();

    return FutureBuilder<List<Product>>(
        future: products,
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
                      value: item.product,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none),
                      style: const TextStyle(fontSize: 13, color: Colors.black),
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
                    child: Text('₹${item.netAmount.toStringAsFixed(0)}',
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
          fillColor: Colors.white,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
            label: 'Lorry Fill Progress',
            value: _totalQtl,
            max: _capacity,
            suffix: 'QTL',
            color: _totalQtl / _capacity > 0.9
                ? Colors.orange
                : AppTheme.primaryGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewPage() {
    return SafePage(
      child: SafeColumn(
        children: [
          SafeCard(
            child: SafeColumn(
              children: [
                _summaryRow('Total Customers',
                    '${_customers.where((c) => c.isValid).length}'),
                _summaryRow(
                    'Total Weight', '${_totalQtl.toStringAsFixed(2)} QTL'),
                _summaryRow(
                    'Total Value', '₹${_totalAmount.toStringAsFixed(0)}',
                    isPrimary: true),
                const Divider(height: 32),
                SwitchListTile(
                  title: const Text('Send Email to Mill'),
                  value: _sendEmail,
                  onChanged: (v) => setState(() => _sendEmail = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Customer Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._customers.where((c) => c.isValid).map((c) => SafeCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.zero,
                child: SafeListTile(
                  title: c.customer!.shopName,
                  subtitle:
                      '${c.items.length} Varieties - ${c.totalQtl.toStringAsFixed(2)} QTL',
                  trailing: SafeText('₹${c.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen)),
                ),
              )),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep = 1),
              child: const Text('Back to Editing'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeRow(
        leading: Text(label, style: const TextStyle(color: AppTheme.grey)),
        trailing: SafeText(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isPrimary ? 20 : 16,
                color: isPrimary ? AppTheme.primaryGreen : AppTheme.charcoal)),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return SafeColumn(
      children: [
        SafeText(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppTheme.grey,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SafeRow(
          leading: Icon(icon, size: 14, color: AppTheme.primaryGreen),
          trailing: SafeText(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
