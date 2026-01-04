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

  // Calculations
  double get kgTotal => (bags26 * 26.0) + (bags10 * 10.0) + (bags5 * 5.0);
  double get qtlTotal => kgTotal / 100.0;
  double get baseAmount => qtlTotal * rate;
  double get amcPercent => 1.0; // Fixed 1%
  double get amcAmount => baseAmount * (amcPercent / 100);

  double get gstPercent {
    // If any 5kg or 10kg bags are used, GST is 5%
    if (bags10 > 0 || bags5 > 0) return 5.0;
    // Otherwise, use product's default GST
    return product?.gstRateDefault ?? 0.0;
  }

  double get gstAmount => (baseAmount + amcAmount) * (gstPercent / 100);
  double get netAmount => baseAmount + amcAmount + gstAmount;

  bool get isValid =>
      product != null && (bags26 > 0 || bags10 > 0 || bags5 > 0) && rate > 0;
}

/// Lorry Based Order Screen
/// ONE ORDER REPRESENTS ONE LORRY LOAD.
/// A single order can contain multiple customers, each with multiple rice varieties.
class NewOrderScreen extends ConsumerStatefulWidget {
  final Customer? preselectedCustomer;
  final String? duplicateOrderId;

  const NewOrderScreen(
      {super.key, this.preselectedCustomer, this.duplicateOrderId});

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  int _currentStep = 1; // 1: Build Lorry, 2: Review & Send
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

  Future<void> _initLorry() async {
    final db = ref.read(databaseProvider);
    final orderCount = await db.select(db.orders).get();
    final nextNum =
        await SettingsService.generateOrderNumber(orderCount.length);
    setState(() {
      _orderNumber = nextNum;
    });

    // Start with one customer or load duplicate
    if (widget.duplicateOrderId != null) {
      await _loadDuplicateData(widget.duplicateOrderId!, db);
    } else {
      _addCustomer(initial: widget.preselectedCustomer);
    }
  }

  Future<void> _loadDuplicateData(String orderId, AppDatabase db) async {
    try {
      // 1. Fetch original order for capacity/notes
      final originalOrder = await (db.select(db.orders)
            ..where((tbl) => tbl.id.equals(orderId)))
          .getSingle();

      _capacityController.text = originalOrder.lorryCapacity.toString();
      // Optional: keep or clear notes? Let's clear order number to generate new one

      // 2. Fetch shipments (customers)
      final shipmentRows = await (db.select(db.lorryShipments).join([
        drift.innerJoin(db.customers,
            db.customers.id.equalsExp(db.lorryShipments.customerId)),
      ])
            ..where(db.lorryShipments.orderId.equals(orderId)))
          .get();

      // 3. Fetch all items
      final allItems = await (db.select(db.orderItems)
            ..where((tbl) => tbl.orderId.equals(orderId)))
          .get();

      final products = await db.select(db.products).get();

      // 4. Reconstruct UI State
      final loadedCustomers = <CustomerLoadFormData>[];

      for (var row in shipmentRows) {
        final customer = row.readTable(db.customers);
        final shipment = row.readTable(db.lorryShipments);

        // Filter items for this customer
        final myItems =
            allItems.where((i) => i.customerId == customer.id).toList();

        final formItems = myItems.map((i) {
          final product = products.firstWhere((p) => p.id == i.productId,
              orElse: () => Product(
                  id: '?',
                  name: 'Unknown',
                  defaultPrice: 0,
                  gstRateDefault: 0,
                  unit: '',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now()));

          return OrderItemFormData(
            product: product,
            bags26: i.bags26,
            bags10: i.bags10,
            bags5: i.bags5,
            rate: i.ratePerQtl,
          );
        }).toList();

        // If no items found (edge case), add empty line
        if (formItems.isEmpty) formItems.add(OrderItemFormData());

        loadedCustomers.add(CustomerLoadFormData(
            customer: customer,
            items: formItems,
            paymentStatus: shipment
                .paymentStatus, // Copy status or reset? Usually duplicate means new active order, so maybe reset to UNPAID. keeping for ref.
            dueDate: shipment.dueDate));
      }

      // Handle Legacy (Single Customer) Orders if LorryShipments is empty
      if (loadedCustomers.isEmpty && originalOrder.customerId != null) {
        final legacyCustomer = await (db.select(db.customers)
              ..where((t) => t.id.equals(originalOrder.customerId!)))
            .getSingleOrNull();
        if (legacyCustomer != null) {
          final myItems =
              allItems; // complex legacy mapping omitted for brevity, usually items have customerId now.
          // If items don't have customerId (legacy v1), assume they belong to this customer
          final formItems = myItems.map((i) {
            final product = products.firstWhere((p) => p.id == i.productId,
                orElse: () => Product(
                    id: '?',
                    name: 'Unknown',
                    defaultPrice: 0,
                    gstRateDefault: 0,
                    unit: '',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now()));
            return OrderItemFormData(
              product: product,
              bags26: i.bags26,
              bags10: i.bags10,
              bags5: i.bags5,
              rate: i.ratePerQtl,
            );
          }).toList();

          loadedCustomers.add(CustomerLoadFormData(
              customer: legacyCustomer,
              items: formItems.isEmpty ? [OrderItemFormData()] : formItems));
        }
      }

      if (loadedCustomers.isNotEmpty) {
        setState(() {
          _customers.clear();
          _customers.addAll(loadedCustomers);
        });
      } else {
        // Fallback
        _addCustomer();
      }
    } catch (e) {
      debugPrint('Duplicate Load Error: $e');
      _addCustomer();
    }
  }

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

  // Totals
  double get _totalQtl => _customers.fold(0, (sum, c) => sum + c.totalQtl);
  double get _totalAmount =>
      _customers.fold(0, (sum, c) => sum + c.totalAmount);
  double get _capacity => double.tryParse(_capacityController.text) ?? 210.0;
  double get _fillProgress => (_totalQtl / _capacity).clamp(0.0, 1.0);

  Future<void> _saveLorryOrder() async {
    // Validation
    if (_customers.every((c) => !c.isValid)) {
      _showError('Please add at least one customer with valid items');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final lorryId = DateTime.now().millisecondsSinceEpoch.toString();

      await db.transaction(() async {
        // 1. Create Lorry (Orders table)
        await db.into(db.orders).insert(OrdersCompanion(
              id: drift.Value(lorryId),
              loadingDate: drift.Value(_loadingDate),
              totalAmount: drift.Value(_totalAmount),
              lorryCapacity: drift.Value(_capacity),
              notes: drift.Value(_orderNumber),
              createdAt: drift.Value(DateTime.now()),
              updatedAt: drift.Value(DateTime.now()),
            ));

        // 2. Process each customer
        for (var customerLoad in _customers) {
          if (!customerLoad.isValid) continue;

          final cId = customerLoad.customer!.id;

          // Add Lorry Shipment (per-customer tracking)
          await db.into(db.lorryShipments).insert(LorryShipmentsCompanion(
                id: drift.Value('${lorryId}_$cId'),
                orderId: drift.Value(lorryId),
                customerId: drift.Value(cId),
                totalAmount: drift.Value(customerLoad.totalAmount),
                paymentStatus: drift.Value(customerLoad.paymentStatus),
                dueDate: drift.Value(customerLoad.dueDate),
              ));

          // Add items
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

      // 3. Generate Excel
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
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Lorry Order saved successfully!'),
              backgroundColor: AppTheme.success),
        );

        // Navigate back first
        Navigator.pop(context);

        // 4. Optionally share via email if toggle was on
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
                    child: const Text('Later'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Share Now'),
                  ),
                ],
              ),
            );

            if (shouldShare == true && context.mounted) {
              try {
                final success = await EmailService.shareOrderExcel(
                  filePath: excelPath,
                  customerName: "Multi-Customer Lorry",
                  orderNumber: _orderNumber ?? lorryId,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Order shared successfully!'
                          : 'Failed to share order'),
                      backgroundColor:
                          success ? AppTheme.success : AppTheme.error,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error sharing: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            }
          }
        }
      }
    } catch (e, stack) {
      debugPrint('SAVE ERROR: $e\n$stack');
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
        title: Text(_currentStep == 1 ? 'Build Lorry Load' : 'Review & Send'),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Lorry Info Card
        _buildSectionCard(
          title: 'Step 1: Lorry Details',
          icon: Icons.local_shipping_outlined,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                        'Order #', _orderNumber ?? '...', Icons.tag),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _loadingDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) setState(() => _loadingDate = date);
                      },
                      child: _buildInfoItem(
                          'Loading Date',
                          DateFormat('dd MMM yyyy').format(_loadingDate),
                          Icons.calendar_today),
                    ),
                  ),
                ],
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
        const SizedBox(height: 24),

        // Customers Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Step 2: Add Customers',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            TextButton.icon(
                onPressed: () => _addCustomer(),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Customer')),
          ],
        ),
        const SizedBox(height: 8),

        // Customer Cards
        ..._customers
            .asMap()
            .entries
            .map((entry) => _buildCustomerCard(entry.key, entry.value)),

        const SizedBox(height: 100), // Space for footer
      ],
    );
  }

  Widget _buildCustomerCard(int index, CustomerLoadFormData data) {
    final db = ref.watch(databaseProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.lightGrey),
      ),
      child: Column(
        children: [
          // Header
          ListTile(
            onTap: () => setState(() => data.isExpanded = !data.isExpanded),
            leading: CircleAvatar(
              backgroundColor: AppTheme.paleGreen,
              radius: 18,
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold)),
            ),
            title: data.customer == null
                ? const Text('Select Customer',
                    style: TextStyle(
                        color: AppTheme.grey, fontStyle: FontStyle.italic))
                : Text(data.customer!.shopName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: data.customer != null
                ? Text(data.customer!.place ?? 'No place')
                : null,
            trailing: IconButton(
              icon:
                  Icon(data.isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () =>
                  setState(() => data.isExpanded = !data.isExpanded),
            ),
          ),

          if (data.isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Selector Search Bar
                  if (data.customer == null)
                    StreamBuilder<List<Customer>>(
                      stream: db.select(db.customers).watch(),
                      builder: (context, snapshot) {
                        final allCustomers = snapshot.data ?? [];
                        return SearchAnchor(
                          builder: (BuildContext context,
                              SearchController controller) {
                            return SearchBar(
                              controller: controller,
                              padding: const WidgetStatePropertyAll<EdgeInsets>(
                                  EdgeInsets.symmetric(horizontal: 16.0)),
                              onTap: () {
                                controller.openView();
                              },
                              onChanged: (_) {
                                controller.openView();
                              },
                              leading: const Icon(Icons.search),
                              hintText: 'Search Shop or Phone...',
                            );
                          },
                          suggestionsBuilder: (BuildContext context,
                              SearchController controller) {
                            final keyword = controller.text.toLowerCase();
                            final filtered = allCustomers.where((c) {
                              final name = c.shopName.toLowerCase();
                              final phone = (c.phone ?? '').toLowerCase();
                              return name.contains(keyword) ||
                                  phone.contains(keyword);
                            }).toList();

                            return filtered.map((c) {
                              return cfListTile(c, () {
                                setState(() {
                                  data.customer = c;
                                  controller.closeView(null);
                                });
                              });
                            });
                          },
                        );
                      },
                    ),

                  if (data.customer != null) ...[
                    // Varieties Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Rice Varieties',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        TextButton.icon(
                          onPressed: () => setState(
                              () => data.items.add(OrderItemFormData())),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Add Variety',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),

                    // Items Table
                    StreamBuilder<List<Product>>(
                        stream: db.select(db.products).watch(),
                        builder: (context, snapshot) {
                          final products = snapshot.data ?? [];
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTableHeader(),
                                ...data.items.asMap().entries.map((itemEntry) =>
                                    _buildItemRow(data, itemEntry.key,
                                        itemEntry.value, products)),
                              ],
                            ),
                          );
                        }),

                    const SizedBox(height: 16),
                    // Customer Total Mini-Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: AppTheme.paleGreen,
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('SUB-TOTAL',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen)),
                          Text('${data.totalQtl.toStringAsFixed(2)} QTL',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text('₹${data.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  // Actions for card
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.error),
                        onPressed: () => _removeCustomer(index),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove Party'),
                      ),
                    ],
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
          color: AppTheme.lightGrey, borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          _columnHeader('Rice Variety', 140),
          _columnHeader('26kg', 60),
          _columnHeader('10kg', 60),
          _columnHeader('5kg', 60),
          _columnHeader('Rate', 80),
          _columnHeader('QTL', 60),
          _columnHeader('Amount', 100),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _columnHeader(String label, double width) {
    return SizedBox(
        width: width,
        child: Text(label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center));
  }

  Widget _buildItemRow(CustomerLoadFormData data, int index,
      OrderItemFormData item, List<Product> products) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<Product>(
                initialValue: item.product,
                isExpanded: true,
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.zero, border: InputBorder.none),
                style: const TextStyle(fontSize: 13, color: Colors.black),
                items: products
                    .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    item.product = val;
                    item.rate = val?.defaultPrice ?? 0;
                  });
                },
              ),
            ),
          ),
          _itemInput(60, item.bags26.toString(),
              (v) => setState(() => item.bags26 = int.tryParse(v) ?? 0)),
          _itemInput(60, item.bags10.toString(),
              (v) => setState(() => item.bags10 = int.tryParse(v) ?? 0)),
          _itemInput(60, item.bags5.toString(),
              (v) => setState(() => item.bags5 = int.tryParse(v) ?? 0)),
          _itemInput(80, item.rate.toStringAsFixed(0),
              (v) => setState(() => item.rate = double.tryParse(v) ?? 0)),
          SizedBox(
              width: 60,
              child: Text(item.qtlTotal.toStringAsFixed(2),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center)),
          SizedBox(
              width: 100,
              child: Text('₹${item.netAmount.toStringAsFixed(1)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: Icon(Icons.close,
                  size: 16, color: AppTheme.error.withValues(alpha: 0.5)),
              onPressed: () => setState(() => data.items.removeAt(index)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemInput(double width, String initial, Function(String) onChanged) {
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
        controller: TextEditingController(
            text: initial == '0' || initial == '0.0' ? '' : initial)
          ..selection = TextSelection.collapsed(
              offset:
                  (initial == '0' || initial == '0.0' ? '' : initial).length),
      ),
    );
  }

  Widget _buildLorryProgressFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppTheme.lightGrey)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text('Lorry Fill Progress',
                      style: Theme.of(context).textTheme.labelMedium,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                      '${_totalQtl.toStringAsFixed(2)} / ${_capacity.toStringAsFixed(0)} QTL',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _fillProgress,
                minHeight: 12,
                backgroundColor: AppTheme.lightGrey,
                valueColor: AlwaysStoppedAnimation(_fillProgress > 0.9
                    ? Colors.orange
                    : AppTheme.primaryGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'Lorry Summary',
          icon: Icons.summarize_outlined,
          child: Column(
            children: [
              _summaryRow('Total Customers',
                  '${_customers.where((c) => c.isValid).length}'),
              _summaryRow(
                  'Total Load Weight', '${_totalQtl.toStringAsFixed(2)} QTL'),
              _summaryRow(
                  'Total Order Value', '₹${_totalAmount.toStringAsFixed(2)}',
                  isPrimary: true),
              const Divider(height: 32),
              SwitchListTile(
                title: const Text('Send to Mill via Email'),
                subtitle: const Text('Attach Excel auto-generated report'),
                value: _sendEmail,
                onChanged: (v) => setState(() => _sendEmail = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Customer Breakdown',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._customers.where((c) => c.isValid).map((c) => Card(
              child: ListTile(
                title: Text(c.customer!.shopName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${c.items.length} Rice Varieties'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${c.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                            fontSize: 16)),
                    Text('${c.totalQtl.toStringAsFixed(2)} QTL',
                        style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => setState(() => _currentStep = 1),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lightGrey,
              foregroundColor: AppTheme.charcoal),
          child: const Text('Back to Editing'),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.grey)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isPrimary ? 20 : 16,
                  color:
                      isPrimary ? AppTheme.primaryGreen : AppTheme.charcoal)),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.lightGrey)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppTheme.primaryGreen),
            const SizedBox(width: 12),
            Text(title,
                style: const TextStyle(
                    color: AppTheme.primaryGreen, fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppTheme.grey,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(children: [
          Icon(icon, size: 14, color: AppTheme.primaryGreen),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
        ]),
      ],
    );
  }

  Widget cfListTile(Customer c, VoidCallback onTap) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.paleGreen,
        child: Text(c.shopName.isNotEmpty ? c.shopName[0] : '?',
            style: const TextStyle(color: AppTheme.primaryGreen)),
      ),
      title: Text(c.shopName),
      subtitle: Text('${c.place ?? ""} ${c.phone ?? ""}'),
      onTap: onTap,
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
