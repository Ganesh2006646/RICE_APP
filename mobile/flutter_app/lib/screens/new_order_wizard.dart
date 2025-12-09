import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../main.dart';
import '../db/database.dart';

class NewOrderWizard extends ConsumerStatefulWidget {
  const NewOrderWizard({super.key});

  @override
  ConsumerState<NewOrderWizard> createState() => _NewOrderWizardState();
}

class OrderItemData {
  Product product;
  int bags26;
  int bags10;
  int bags5;
  double ratePerQtl;

  // Computed properties
  double get qtyKg => (bags26 * 26.0) + (bags10 * 10.0) + (bags5 * 5.0);
  double get qtyQtl => qtyKg / 100.0;
  double get lineAmount => qtyQtl * ratePerQtl;

  // Tax Logic
  double get amcPercent => 1.0; // Fixed 1%
  double get amcAmount => lineAmount * (amcPercent / 100.0);

  double get gstPercent {
    // If any small bags are used, GST is always 5% (rule of thumb from specs, implies retail packs)
    if (bags10 > 0 || bags5 > 0) return 5.0;
    // For 26kg only, it depends on the product's default tax setting
    return product.gstRateDefault;
  }

  double get gstAmount => (lineAmount + amcAmount) * (gstPercent / 100.0);
  double get netAmount => lineAmount + amcAmount + gstAmount;

  OrderItemData(
      {required this.product,
      this.bags26 = 0,
      this.bags10 = 0,
      this.bags5 = 0,
      required this.ratePerQtl});
}

class _NewOrderWizardState extends ConsumerState<NewOrderWizard> {
  int _currentStep = 0;
  Customer? _selectedCustomer;
  List<OrderItemData> _items = [];
  final _dateFormat = DateFormat('dd/MM/yyyy');

  void _nextStep() {
    if (_currentStep == 0 && _selectedCustomer == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a customer')));
      return;
    }
    if (_currentStep == 1 && _items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least one item')));
      return;
    }
    if (_currentStep == 2) {
      _saveOrder();
      return;
    }
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _saveOrder() async {
    final db = ref.read(databaseProvider);
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final grandTotal = _items.fold(0.0, (sum, item) => sum + item.netAmount);

    await db.transaction(() async {
      await db.into(db.orders).insert(OrdersCompanion(
            id: drift.Value(orderId),
            customerId: drift.Value(_selectedCustomer!.id),
            loadingDate: drift.Value(DateTime.now()), // Default to today
            totalAmount: drift.Value(grandTotal),
            isSynced: const drift.Value(false),
            createdAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
          ));

      for (var item in _items) {
        await db.into(db.orderItems).insert(OrderItemsCompanion(
              id: drift.Value(
                  '${orderId}_${item.product.id}_${DateTime.now().microsecondsSinceEpoch}'), // Unique ID
              orderId: drift.Value(orderId),
              productId: drift.Value(item.product.id),
              bags26: drift.Value(item.bags26),
              bags10: drift.Value(item.bags10),
              bags5: drift.Value(item.bags5),
              qtyKg: drift.Value(item.qtyKg),
              qtyQtl: drift.Value(item.qtyQtl),
              ratePerQtl: drift.Value(item.ratePerQtl),
              amcPercent: drift.Value(item.amcPercent),
              gstPercent: drift.Value(item.gstPercent),
              lineAmount: drift.Value(item.lineAmount),
              amcAmount: drift.Value(item.amcAmount),
              gstAmount: drift.Value(item.gstAmount),
              netAmount: drift.Value(item.netAmount),
            ));
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order saved successfully!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Order')),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: _nextStep,
        onStepCancel: _prevStep,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Row(
              children: [
                FilledButton(
                    onPressed: details.onStepContinue,
                    child: Text(_currentStep == 2 ? 'Save Order' : 'Next')),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  OutlinedButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back')),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Party'),
            content: _buildCustomerStep(),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.editing,
          ),
          Step(
            title: const Text('Items'),
            content: _buildItemsStep(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.editing,
          ),
          Step(
            title: const Text('Review'),
            content: _buildReviewStep(),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerStep() {
    final db = ref.watch(databaseProvider);
    return SizedBox(
      height: 400, // Constrain height
      child: StreamBuilder<List<Customer>>(
        stream: db.select(db.customers).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final customers = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Customer',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<Customer>(
                value: _selectedCustomer,
                isExpanded: true,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                    labelText: 'Shop / Party Name'),
                items: customers
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.shopName} (${c.place ?? 'Unknown'})')))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCustomer = v),
              ),
              if (_selectedCustomer != null) ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Details',
                            style: Theme.of(context).textTheme.titleMedium),
                        const Divider(),
                        Text('Owner: ${_selectedCustomer!.ownerName ?? '-'}'),
                        Text('Place: ${_selectedCustomer!.place ?? '-'}'),
                        Text('GST: ${_selectedCustomer!.tinGst ?? '-'}'),
                        Text('Phone: ${_selectedCustomer!.phone ?? '-'}'),
                      ],
                    ),
                  ),
                )
              ]
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemsStep() {
    final db = ref.watch(databaseProvider);
    return Column(
      children: [
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Text('No items added yet. Click "Add Item" below.'),
          ),
        ..._items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(item.product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '26kg: ${item.bags26} | 10kg: ${item.bags10} | 5kg: ${item.bags5}'),
                  Text(
                      'Total: ${item.qtyQtl.toStringAsFixed(2)} QTL @ ₹${item.ratePerQtl}'),
                  Text(
                      'Net: ₹${item.netAmount.toStringAsFixed(2)} (inc. AMC 1%, GST ${item.gstPercent.toStringAsFixed(0)}%)',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => setState(() => _items.removeAt(index)),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Item'),
          style:
              ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: () => _showAddItemDialog(db),
        ),
      ],
    );
  }

  void _showAddItemDialog(AppDatabase db) {
    Product? selectedProduct;
    final b26Ctrl = TextEditingController(text: '0');
    final b10Ctrl = TextEditingController(text: '0');
    final b5Ctrl = TextEditingController(text: '0');
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Add Order Item'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<List<Product>>(
                stream: db.select(db.products).watch(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  return DropdownButtonFormField<Product>(
                    value: selectedProduct,
                    hint: const Text('Select Rice Variety'),
                    isExpanded: true,
                    items: snapshot.data!
                        .map((p) =>
                            DropdownMenuItem(value: p, child: Text(p.name)))
                        .toList(),
                    onChanged: (v) {
                      setStateDialog(() {
                        selectedProduct = v;
                        priceCtrl.text = v?.defaultPrice.toString() ?? '';
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: b26Ctrl,
                        decoration:
                            const InputDecoration(labelText: '26 kg Bags'),
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: b10Ctrl,
                        decoration:
                            const InputDecoration(labelText: '10 kg Bags'),
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: b5Ctrl,
                        decoration:
                            const InputDecoration(labelText: '5 kg Bags'),
                        keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 16),
              TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Rate per Quintal (₹)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (selectedProduct == null) return;
                final b26 = int.tryParse(b26Ctrl.text) ?? 0;
                final b10 = int.tryParse(b10Ctrl.text) ?? 0;
                final b5 = int.tryParse(b5Ctrl.text) ?? 0;
                final rate = double.tryParse(priceCtrl.text) ?? 0.0;

                if (b26 == 0 && b10 == 0 && b5 == 0)
                  return; // Must have some bags

                setState(() {
                  _items.add(OrderItemData(
                      product: selectedProduct!,
                      bags26: b26,
                      bags10: b10,
                      bags5: b5,
                      ratePerQtl: rate));
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    if (_selectedCustomer == null) return const SizedBox();
    final grandTotal = _items.fold(0.0, (sum, item) => sum + item.netAmount);
    final totalQtl = _items.fold(0.0, (sum, item) => sum + item.qtyQtl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_selectedCustomer!.shopName,
            style: Theme.of(context).textTheme.headlineSmall),
        Text('Date: ${_dateFormat.format(DateTime.now())}'),
        const Divider(thickness: 2),
        ..._items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(flex: 3, child: Text(item.product.name)),
                  Expanded(
                      flex: 2,
                      child: Text('${item.qtyQtl.toStringAsFixed(2)} Q')),
                  Expanded(
                      flex: 2,
                      child: Text('₹${item.netAmount.toStringAsFixed(0)}')),
                ],
              ),
            )),
        const Divider(thickness: 2),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Qty',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${totalQtl.toStringAsFixed(2)} QTL',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Grand Total',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('₹${grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.green)),
          ],
        ),
      ],
    );
  }
}
