import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../main.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../db/database.dart';
import '../services/excel_service.dart';
import '../services/settings_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/safe_widgets.dart';
import '../widgets/capacity_progress_card.dart';
import '../widgets/confirm_dialog.dart';

// ── Data Classes (unchanged) ──────────────────────────────────────────────────

class OrderItemFormData {
  Product? product;
  int bags26;
  int bags10;
  int bags5;
  double rate;

  double packingPrice10;
  double packingPrice5;
  double amcRate;
  double gstRate;

  OrderItemFormData({
    this.product,
    this.bags26 = 0,
    this.bags10 = 0,
    this.bags5 = 0,
    this.rate = 0,
    this.packingPrice10 = 200.0,
    this.packingPrice5 = 250.0,
    this.amcRate = 0.01,
    this.gstRate = 0.05,
  });

  static const double _fixedAmcRate = 0.01;

  bool get supports10Kg => _supportsPackFromUnit(product?.unit, 10);
  bool get supports5Kg => _supportsPackFromUnit(product?.unit, 5);

  int get applicableBags10 => supports10Kg ? bags10 : 0;
  int get applicableBags5 => supports5Kg ? bags5 : 0;

  double get effectiveGstRate => (product?.gstRateDefault ?? 0) / 100.0;

  double get kg26 => bags26 * 26.0;
  double get kg10 => applicableBags10 * 10.0;
  double get kg5 => applicableBags5 * 5.0;
  double get kgTotal => kg26 + kg10 + kg5;
  double get qtlTotal => kgTotal / 100.0;

  // ── Effective rates: packing surcharge baked into per-QTL rate ────────────
  // Bulk discount (which reduces `rate`) therefore also cuts into packing cost.
  double get effectiveRate26 => rate;                   // 26 kg: no packing
  double get effectiveRate10 => rate + packingPrice10;  // 10 kg: rate + surcharge
  double get effectiveRate5  => rate + packingPrice5;   //  5 kg: rate + surcharge

  // ── Base values (effective rate × QTL) ────────────────────────────────────
  double get value26     => (effectiveRate26 / 100.0) * 26.0 * bags26;
  double get baseValue10 => (effectiveRate10 / 100.0) * 10.0 * applicableBags10;
  double get baseValue5  => (effectiveRate5  / 100.0) *  5.0 * applicableBags5;

  /// Finalized base price shown in Review & Excel (packing already included).
  double get baseAmount => value26 + baseValue10 + baseValue5;

  /// Weighted effective rate per QTL across all bag types (for display chips).
  double get weightedEffectiveRate =>
      qtlTotal > 0 ? baseAmount / qtlTotal : rate;

  // ── AMC: 1% on effective base value ──────────────────────────────────────
  double get amc26 => value26     * _fixedAmcRate;
  double get amc10 => baseValue10 * _fixedAmcRate;
  double get amc5  => baseValue5  * _fixedAmcRate;

  // ── GST: on (base + AMC), 10 kg & 5 kg only ─────────────────────────────
  double get gst10 => (baseValue10 + amc10) * effectiveGstRate;
  double get gst5  => (baseValue5  + amc5)  * effectiveGstRate;

  // ── Line totals ───────────────────────────────────────────────────────────
  double get total26 => value26     + amc26;
  double get total10 => baseValue10 + amc10 + gst10;
  double get total5  => baseValue5  + amc5  + gst5;

  double get netAmount => total26 + total10 + total5;
  double get amcAmount => amc26 + amc10 + amc5;
  double get gstAmount => gst10 + gst5;

  // ── GST taxable base (for DB storage / percentage display) ───────────────
  double get taxableSubtotal => (baseValue10 + amc10) + (baseValue5 + amc5);

  // ── Packing / subtotal aliases (kept for test compatibility) ─────────────
  // packing = (effectiveRate - baseRate) × qtl
  double get packing10 => packingPrice10 * (applicableBags10 * 10.0 / 100.0);
  double get packing5  => packingPrice5  * (applicableBags5  *  5.0 / 100.0);
  double get subtotal10 => baseValue10; // base already includes packing
  double get subtotal5  => baseValue5;  // base already includes packing

  double get amcPercent => _fixedAmcRate * 100.0;
  double get gstPercent {
    if (taxableSubtotal == 0) return 0.0;
    return (gstAmount / taxableSubtotal) * 100.0;
  }

  bool get isValid =>
      product != null &&
      bags26 >= 0 &&
      bags10 >= 0 &&
      bags5 >= 0 &&
      (bags26 > 0 || applicableBags10 > 0 || applicableBags5 > 0) &&
      rate > 0;

  static bool _supportsPackFromUnit(String? unit, int packKg) {
    if (unit == null || unit.isEmpty) return true;
    final match =
        RegExp('p$packKg:(0|1)', caseSensitive: false).firstMatch(unit);
    if (match == null) return true;
    return match.group(1) == '1';
  }
}

class CustomerLoadFormData {
  Customer? customer;
  final List<OrderItemFormData> items;
  bool isExpanded;
  String paymentStatus;
  DateTime? dueDate;

  CustomerLoadFormData({
    this.customer,
    required this.items,
    this.isExpanded = true,
    this.paymentStatus = 'UNPAID',
    this.dueDate,
  });

  double get totalQtl =>
      items.fold(0, (sum, item) => sum + (item.isValid ? item.qtlTotal : 0));
  double get totalAmount =>
      items.fold(0, (sum, item) => sum + (item.isValid ? item.netAmount : 0));
  bool get isValid => customer != null && items.any((item) => item.isValid);
}

// ── Screen ──────────────────────────────────────────────────────────────────

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
  static const int _totalSteps = 5;
  DateTime _loadingDate = DateTime.now().add(const Duration(days: 1));
  final TextEditingController _capacityController =
      TextEditingController(text: '120');
  final TextEditingController _orderNumberController = TextEditingController();
  final Map<String, int> _inputFieldRevisions = {};
  final Map<int, double> _bulkDiscountBaseRates = {};
  final Map<int, double> _bulkDiscountLastAppliedRates = {};
  final List<CustomerLoadFormData> _customers = [];
  bool _isSaving = false;
  String? _orderNumber;
  List<Product> _cachedProducts = [];
  bool _productsLoaded = false;

  @override
  void initState() {
    super.initState();
    _initLorry();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final db = ref.read(databaseProvider);
    final products = await db.select(db.products).get();
    if (mounted) {
      setState(() {
        _cachedProducts = products;
        _productsLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _capacityController.dispose();
    _orderNumberController.dispose();
    super.dispose();
  }

  void _resetState() {
    _currentStep = 1;
    _isSaving = false;
    _customers.clear();
    _inputFieldRevisions.clear();
    _loadingDate = DateTime.now().add(const Duration(days: 1));
    _orderNumber = null;
  }

  Widget _buildLoadingFallback() {
    return const Center(
      child: SafeColumn(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          SafeText('Loading...', style: TextStyle(color: AppColors.primary)),
        ],
      ),
    );
  }

  Future<void> _initLorry() async {
    final db = ref.read(databaseProvider);
    final orderCount = await db.select(db.orders).get();
    final nextNum =
        await SettingsService.generateOrderNumber(orderCount.length);
    if (!mounted) return;
    setState(() {
      _orderNumber = nextNum;
      _orderNumberController.text = nextNum;
    });
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
      if (!mounted) return;
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
            packingPrice10: ref.read(settingsProvider).packing10Price,
            packingPrice5: ref.read(settingsProvider).packing5Price,
            amcRate: 0.01,
            gstRate: ref.read(settingsProvider).gstPercent / 100.0,
          );
        }).toList();
        if (formItems.isEmpty) formItems.add(_createFormItem());
        loadedCustomers
            .add(CustomerLoadFormData(customer: customer, items: formItems));
      }
      if (loadedCustomers.isNotEmpty) {
        if (mounted) {
          setState(() {
            _customers.clear();
            _customers.addAll(loadedCustomers);
          });
        }
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
      isGalaxy: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now());

  OrderItemFormData _createFormItem(
      {Product? product,
      int bags26 = 0,
      int bags10 = 0,
      int bags5 = 0,
      double rate = 0}) {
    final settings = ref.read(settingsProvider);
    return OrderItemFormData(
      product: product,
      bags26: bags26,
      bags10: bags10,
      bags5: bags5,
      rate: rate,
      packingPrice10: settings.packing10Price,
      packingPrice5: settings.packing5Price,
      amcRate: 0.01,
      gstRate: settings.gstPercent / 100.0,
    );
  }

  void _addCustomer({Customer? initial}) {
    // ── Duplicate guard ────────────────────────────────────────────────────
    if (initial != null) {
      final alreadyAdded = _customers.any((c) => c.customer?.id == initial.id);
      if (alreadyAdded) {
        _showError('${initial.shopName} is already in this order');
        return;
      }
    }
    setState(() {
      _customers.add(
          CustomerLoadFormData(customer: initial, items: [_createFormItem()]));
    });
  }

  void _removeCustomer(int index) {
    if (_customers.length > 1) {
      setState(() {
        final removed = _customers.removeAt(index);
        for (final item in removed.items) {
          _clearItemInputRevisions(item);
        }
      });
    }
  }

  double get _totalQtl => _customers.fold(0.0, (sum, c) => sum + c.totalQtl);
  double get _totalAmount =>
      _customers.fold(0.0, (sum, c) => sum + (c.isValid ? c.totalAmount : 0.0));
  double get _capacity => double.tryParse(_capacityController.text) ?? 120.0;

  void _bumpInputRevision(String fieldKey) {
    _inputFieldRevisions[fieldKey] = (_inputFieldRevisions[fieldKey] ?? 0) + 1;
  }

  void _clearItemInputRevisions(OrderItemFormData item) {
    _inputFieldRevisions.remove('${item.hashCode}_bags26');
    _inputFieldRevisions.remove('${item.hashCode}_bags10');
    _inputFieldRevisions.remove('${item.hashCode}_bags5');
    _inputFieldRevisions.remove('${item.hashCode}_rate');
    _bulkDiscountBaseRates.remove(item.hashCode);
    _bulkDiscountLastAppliedRates.remove(item.hashCode);
  }

  void _applyBulkDiscounts({bool showSummary = true}) {
    final List<String> discountLog = [];
    setState(() {
      for (var customerData in _customers) {
        if (!customerData.isValid) continue;
        double customerTotalQtl = customerData.totalQtl;
        Map<String, double> varietyQtl = {};
        Map<String, Product> varietyProduct = {};
        for (var item in customerData.items) {
          if (item.product != null) {
            final pid = item.product!.id;
            varietyQtl[pid] = (varietyQtl[pid] ?? 0.0) + item.qtlTotal;
            varietyProduct[pid] = item.product!;
          }
        }
        final eligibleVarieties = <String, double>{};
        final excludedNames = <String>[];
        for (var entry in varietyQtl.entries) {
          final prod = varietyProduct[entry.key];
          if (prod != null) {
            if (prod.isGalaxy) {
              eligibleVarieties[entry.key] = entry.value;
            } else {
              excludedNames.add(prod.name);
            }
          }
        }
        double discountRate = 0.0;
        if (customerTotalQtl >= 100.0) {
          discountRate = 70.0;
        } else if (customerTotalQtl >= 50.0) {
          discountRate = 50.0;
        }
        for (var item in customerData.items) {
          if (item.product == null) continue;
          final itemKey = item.hashCode;
          final lastApplied = _bulkDiscountLastAppliedRates[itemKey];
          final wasUnchangedSinceLastApply =
              lastApplied != null && (item.rate - lastApplied).abs() <= 0.01;

          if (!wasUnchangedSinceLastApply ||
              !_bulkDiscountBaseRates.containsKey(itemKey)) {
            _bulkDiscountBaseRates[itemKey] = item.rate;
          }

          final double currentRate = _bulkDiscountBaseRates[itemKey] ?? item.rate;
          double itemDiscount = 0.0;
          final pid = item.product!.id;
          double itemVarietyQtl = varietyQtl[pid] ?? 0.0;
          if (itemVarietyQtl >= 100.0) {
            itemDiscount = math.max(itemDiscount, 100.0);
          }
          if (discountRate > 0 && eligibleVarieties.containsKey(pid)) {
            itemDiscount = math.max(itemDiscount, discountRate);
          }
          if (itemDiscount > 0) {
            double newRate = math.max(0.0, currentRate - itemDiscount);
            if ((item.rate - newRate).abs() > 0.01) {
              item.rate = newRate;
              _bulkDiscountLastAppliedRates[itemKey] = newRate;
              _bumpInputRevision('${item.hashCode}_rate');
              discountLog.add(
                  '${item.product!.name}: ${item.qtlTotal.toStringAsFixed(1)}QTL → ₹$itemDiscount off (${currentRate.toStringAsFixed(0)} → ${newRate.toStringAsFixed(0)})');
            }
          } else {
            _bulkDiscountLastAppliedRates[itemKey] = currentRate;
          }
        }
      }
    });
    if (showSummary && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Row(children: [
            Icon(Icons.discount, color: Colors.green.shade700),
            const SizedBox(width: 10),
            const Expanded(
                child: Text('Bulk Discount Summary',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ]),
          content: Text(discountLog.join('\n'),
              style: const TextStyle(
                  fontSize: 13, height: 1.4, fontFamily: 'monospace')),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
          ],
        ),
      );
    }
  }

  Future<void> _saveLorryOrder() async {
    if (_customers.every((c) => !c.isValid)) {
      _showError('Please add at least one customer with valid items');
      return;
    }

    // Ensure bulk discounts are always reflected in saved data.
    _applyBulkDiscounts(showSummary: false);

    final confirmed = await ConfirmDialog.show(
      context: context,
      icon: Icons.save_outlined,
      title: 'Confirm Save',
      message: 'Are you sure you want to save this lorry order?',
      confirmLabel: 'Save',
    );
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseProvider);
      final lorryId = generateId();
      await db.transaction(() async {
        await db.into(db.orders).insert(OrdersCompanion(
              id: drift.Value(lorryId),
              loadingDate: drift.Value(_loadingDate),
              totalAmount: drift.Value(_totalAmount),
              lorryCapacity: drift.Value(_capacity),
              notes: drift.Value(_orderNumber),
              createdAt: drift.Value(DateTime.now()),
              updatedAt: drift.Value(DateTime.now()),
              paymentStatus: const drift.Value('UNPAID'),
            ));
        for (var customerLoad in _customers) {
          if (!customerLoad.isValid) continue;
          final cId = customerLoad.customer?.id ?? 'unknown';
          final shipmentId = generateId();
          await db.into(db.lorryShipments).insert(LorryShipmentsCompanion(
                id: drift.Value(shipmentId),
                orderId: drift.Value(lorryId),
                customerId: drift.Value(cId),
                totalAmount: drift.Value(customerLoad.totalAmount),
              ));
          for (var item in customerLoad.items) {
            if (!item.isValid) continue;
            final pId = item.product?.id ?? 'unknown';
            final orderItemId = generateId();
            await db.into(db.orderItems).insert(OrderItemsCompanion(
                  id: drift.Value(orderItemId),
                  orderId: drift.Value(lorryId),
                  customerId: drift.Value(cId),
                  productId: drift.Value(pId),
                  bags26: drift.Value(item.bags26),
                  bags10: drift.Value(item.bags10),
                  bags5: drift.Value(item.bags5),
                  qtyKg: drift.Value(item.kgTotal),
                  qtyQtl: drift.Value(item.qtlTotal),
                  ratePerQtl: drift.Value(item.rate),
                  amcPercent: drift.Value(item.amcPercent),
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
      try {
        final orderNum = _orderNumberController.text.trim().isEmpty
            ? lorryId
            : _orderNumberController.text.trim();
        final path = await ExcelService.generateLorryExcel(
          order: lorryOrder,
          items: allItems,
          customers: validCustomers,
          products: products,
          orderNumber: orderNum,
          settings: ref.read(settingsProvider),
        );
        await ExcelService.copyToDownloads(path,
            customPath: ref.read(settingsProvider).excelSavePath);
      } catch (e) {
        debugPrint('Excel Save Error: $e');
      }
      if (mounted) {
        await ConfirmDialog.showSuccess(
          context: context,
          title: 'Order Saved!',
          message: 'Lorry order saved successfully with Excel export.',
        );
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      _showError('Failed to save order: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    SafeSnackBar.show(context, message, isError: true);
  }

  void _goToStep(int step) {
    if (step < 1 || step > _totalSteps) return;
    if (step > _currentStep) {
      if (!_validateStep()) return;
    }
    // Auto-apply bulk discounts silently when entering Review (step 4+)
    if (step >= 4 && _currentStep <= 3) {
      _applyBulkDiscounts(showSummary: false);
    }
    setState(() => _currentStep = step);
  }

  bool _validateStep() {
    switch (_currentStep) {
      case 1:
        if (_capacity <= 0) {
          _showError('Enter a valid lorry capacity');
          return false;
        }
        return true;
      case 2:
        if (_customers.isEmpty || _customers.every((c) => c.customer == null)) {
          _showError('Select at least one customer');
          return false;
        }
        return true;
      case 3:
        final selectedCustomers =
            _customers.where((c) => c.customer != null).toList();
        if (selectedCustomers.isEmpty) {
          _showError('Select at least one customer');
          return false;
        }

        var hasValidItem = false;
        for (var c in selectedCustomers) {
          for (var item in c.items) {
            final hasAnyInput = item.product != null ||
                item.bags26 > 0 ||
                item.bags10 > 0 ||
                item.bags5 > 0 ||
                item.rate > 0;
            if (!hasAnyInput) continue;
            if (item.product == null) {
              _showError('Select a product for all items');
              return false;
            }
            if (item.rate <= 0) {
              _showError('Rate must be greater than 0');
              return false;
            }
            if ((item.bags26 + item.applicableBags10 + item.applicableBags5) <=
                0) {
              _showError('Enter quantity for at least one supported bag type');
              return false;
            }
            hasValidItem = true;
          }
        }
        if (!hasValidItem) {
          _showError('Add at least one valid order item');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirmed = await ConfirmDialog.show(
          context: context,
          icon: Icons.exit_to_app,
          title: 'Discard Changes?',
          message: 'You have unsaved changes. Discard them?',
          confirmLabel: 'Discard',
          isDanger: true,
        );
        if (confirmed == true && context.mounted) {
          _resetState();
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('New Lorry Order',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Step $_currentStep of $_totalSteps',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
      actions: [
        // Bulk discounts now auto-apply when moving to Review step
        if (_currentStep < _totalSteps)
          TextButton.icon(
            onPressed: () => _goToStep(_currentStep + 1),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Next'),
          )
        else if (_isSaving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          FilledButton.icon(
            onPressed: _saveLorryOrder,
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Save & Send'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    return SafePage(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      backgroundColor: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStepIndicator(),
          const SizedBox(height: AppSpacing.xl),
          _buildStepContent(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: List.generate(_totalSteps * 2 - 1, (index) {
          if (index.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: index ~/ 2 < _currentStep - 1
                    ? AppColors.primary
                    : AppColors.border,
              ),
            );
          }
          final step = index ~/ 2 + 1;
          final isActive = step <= _currentStep;
          final isCurrent = step == _currentStep;
          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppColors.primary : Colors.white,
              border: Border.all(
                color: isActive ? AppColors.primary : AppColors.border,
                width: isCurrent ? 2.5 : 1.5,
              ),
            ),
            child: Center(
              child: isActive
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text('$step',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      )),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Details();
      case 2:
        return _buildStep2Customers();
      case 3:
        return _buildStep3Items();
      case 4:
        return _buildStep4Review();
      case 5:
        return _buildStep5ExportShare();
      default:
        return _buildLoadingFallback();
    }
  }

  // ── STEP 1: Date & Lorry Details ──────────────────────────────────────────

  Widget _buildStep1Details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.info_outline,
                        size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Text('Lorry Details',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _orderNumberController,
                decoration: const InputDecoration(
                  labelText: 'Order Number',
                  prefixIcon: Icon(Icons.tag),
                ),
                onChanged: (v) => _orderNumber = v,
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _loadingDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) setState(() => _loadingDate = date);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Loading Date',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(_loadingDate),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Lorry Capacity (QTL)',
                  prefixIcon: Icon(Icons.balance),
                  helperText: 'Standard lorry capacity is 120 QTL',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── STEP 2: Select Customers ─────────────────────────────────────────────

  Widget _buildStep2Customers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text('Select Customers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addCustomer(),
              icon: const Icon(Icons.person_add, size: 20),
              label: const Text('Add Customer'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ..._customers
            .asMap()
            .entries
            .map((entry) => _buildCustomerSelector(entry.key, entry.value)),
        if (_totalQtl > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: CapacityProgressCard(
              currentQtl: _totalQtl,
              maxCapacity: _capacity,
            ),
          ),
      ],
    );
  }

  Widget _buildCustomerSelector(int index, CustomerLoadFormData data) {
    final db = ref.watch(databaseProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: data.customer != null
                  ? AppColors.primarySurface
                  : AppColors.warningLight,
              radius: 18,
              child: Text(
                data.customer != null
                    ? data.customer!.shopName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: data.customer != null
                      ? AppColors.primary
                      : AppColors.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            title: Text(
              data.customer?.shopName ?? 'Select Customer',
              style: TextStyle(
                fontWeight:
                    data.customer != null ? FontWeight.w600 : FontWeight.w400,
                color: data.customer != null
                    ? AppColors.textPrimary
                    : AppColors.textHint,
              ),
            ),
            subtitle: data.customer?.place != null
                ? Text(data.customer!.place!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary))
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data.customer != null && _customers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        size: 20, color: AppColors.error),
                    onPressed: () => _removeCustomer(index),
                  ),
                if (data.customer != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                    onPressed: () => setState(() => data.customer = null),
                  ),
              ],
            ),
          ),
          if (data.customer == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: StreamBuilder<List<Customer>>(
                stream: db.select(db.customers).watch(),
                builder: (context, snapshot) {
                  final allCustomers = snapshot.data ?? [];
                  return SearchAnchor(
                    builder: (context, controller) => SearchBar(
                      controller: controller,
                      padding: const WidgetStatePropertyAll<EdgeInsets>(
                          EdgeInsets.symmetric(horizontal: 16)),
                      onTap: () => controller.openView(),
                      onChanged: (_) => controller.openView(),
                      leading: const Icon(Icons.search),
                      hintText: 'Search customer...',
                    ),
                    suggestionsBuilder: (context, controller) {
                      // Normalise: trim + lowercase + collapse spaces
                      String norm(String? s) => (s ?? '')
                          .trim()
                          .toLowerCase()
                          .replaceAll(RegExp(r'\s+'), ' ');
                      final keyword = norm(controller.text);
                      final selectedIds = _customers
                          .where((cx) => cx.customer != null && cx != data)
                          .map((cx) => cx.customer!.id)
                          .toSet();
                      final filtered = allCustomers.where((c) {
                        if (selectedIds.contains(c.id)) return false;
                        return norm(c.shopName).contains(keyword) ||
                            norm(c.phone).contains(keyword) ||
                            norm(c.place).contains(keyword);
                      }).toList();
                      return filtered.map((c) => ListTile(
                            title: Text(c.shopName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(c.place ?? ''),
                            trailing: const Icon(Icons.add_circle_outline,
                                size: 20, color: AppColors.primary),
                            onTap: () {
                              // Duplicate guard
                              final isDuplicate = _customers
                                  .where((cx) => cx != data)
                                  .any((cx) => cx.customer?.id == c.id);
                              if (isDuplicate) {
                                controller.closeView(null);
                                _showError(
                                    '${c.shopName} is already in this order');
                                return;
                              }
                              setState(() {
                                data.customer = c;
                              });
                              controller.closeView(null);
                            },
                          ));
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ── STEP 3: Add Items ────────────────────────────────────────────────────

  Widget _buildStep3Items() {
    if (_customers.every((c) => c.customer == null)) {
      return const Center(
          child: Text('Please select customers first.',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._customers
            .asMap()
            .entries
            .map((entry) => _buildCustomerItemsCard(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildCustomerItemsCard(int index, CustomerLoadFormData data) {
    if (data.customer == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(data.customer!.shopName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (data.customer!.place != null)
                        Text(data.customer!.place!,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Flexible(
                  child: Text('${data.totalQtl.toStringAsFixed(1)} QTL',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primary),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          ...data.items.asMap().entries.map((itemEntry) =>
              _buildItemCard(data, itemEntry.key, itemEntry.value)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => data.items.add(_createFormItem())),
                  icon: const Icon(Icons.add, size: 18),
                  label:
                      const Text('Add Variety', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
      CustomerLoadFormData data, int index, OrderItemFormData item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildProductDropdown(item),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon:
                      const Icon(Icons.close, size: 18, color: AppColors.error),
                  onPressed: () {
                    _clearItemInputRevisions(item);
                    setState(() => data.items.removeAt(index));
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _bagInput(
                    '26kg',
                    item.bags26,
                    (v) =>
                        setState(() => item.bags26 = _parseNonNegativeInt(v)),
                    fieldKey: '${item.hashCode}_bags26'),
                const SizedBox(width: 6),
                if (item.supports10Kg)
                  _bagInput(
                      '10kg',
                      item.bags10,
                      (v) =>
                          setState(() => item.bags10 = _parseNonNegativeInt(v)),
                      fieldKey: '${item.hashCode}_bags10')
                else
                  _disabledBagInput('10kg'),
                const SizedBox(width: 6),
                if (item.supports5Kg)
                  _bagInput(
                      '5kg',
                      item.bags5,
                      (v) =>
                          setState(() => item.bags5 = _parseNonNegativeInt(v)),
                      fieldKey: '${item.hashCode}_bags5')
                else
                  _disabledBagInput('5kg'),
                const SizedBox(width: 6),
                Expanded(
                  child: TextFormField(
                    key: ValueKey(
                        '${item.hashCode}_rate:${_inputFieldRevisions['${item.hashCode}_rate'] ?? 0}'),
                    initialValue:
                        item.rate == 0 ? '' : item.rate.toStringAsFixed(0),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Rate',
                      hintStyle: const TextStyle(
                          fontSize: 11, color: AppColors.textHint),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onChanged: (v) =>
                        setState(() => item.rate = _parseNonNegativeDouble(v)),
                  ),
                ),
              ],
            ),
            if (item.isValid)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Text('${_safeQtl(item.qtlTotal)} QTL',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    const Spacer(),
                    Text(
                        '${ref.watch(settingsProvider).currencySymbol}${_safeAmt(item.netAmount)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableProductDropdown(
      OrderItemFormData item, List<Product> productList) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: () => _showProductPicker(item, productList),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.product?.name ?? 'Select variety',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: item.product != null
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.product?.isGalaxy == true)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.star,
                      size: 12, color: AppColors.secondary),
                ),
              const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showProductPicker(
      OrderItemFormData item, List<Product> productList) async {
    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Select Variety',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: productList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final p = productList[i];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: p.isGalaxy
                              ? AppColors.secondarySurface
                              : AppColors.primarySurface,
                          child: Icon(
                            p.isGalaxy ? Icons.star : Icons.grass_outlined,
                            size: 16,
                            color:
                                p.isGalaxy ? AppColors.secondary : AppColors.primary,
                          ),
                        ),
                        title: Text(p.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: p.isGalaxy
                            ? const Icon(Icons.star,
                                size: 16, color: AppColors.secondary)
                            : null,
                        onTap: () => Navigator.pop(ctx, p),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected != null && mounted) {
      setState(() {
        item.product = selected;
        item.rate = selected.defaultPrice;
        if (!item.supports10Kg && item.bags10 > 0) {
          item.bags10 = 0;
          _bumpInputRevision('${item.hashCode}_bags10');
        }
        if (!item.supports5Kg && item.bags5 > 0) {
          item.bags5 = 0;
          _bumpInputRevision('${item.hashCode}_bags5');
        }
        _bumpInputRevision('${item.hashCode}_rate');
      });
    }
  }

  Widget _buildProductDropdown(OrderItemFormData item) {
    if (!_productsLoaded) {
      return const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    // Show ALL products - do not filter by price so varieties like Karthika Blue/Green are always visible
    final list = List<Product>.from(_cachedProducts);
    if (list.isEmpty) {
      return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
          child: Text('No varieties — add from Varieties tab',
              style: TextStyle(fontSize: 12, color: AppColors.textHint)),
        ),
      );
    }
    if (list.length > 8) {
      return _buildScrollableProductDropdown(item, list);
    }
    return DropdownButtonHideUnderline(
      child: DropdownButtonFormField<Product>(
        initialValue: item.product,
        isExpanded: true,
        menuMaxHeight: MediaQuery.of(context).size.height * 0.8,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          border: InputBorder.none,
          filled: false,
        ),
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        hint: const Text('Select variety',
            style: TextStyle(fontSize: 12, color: AppColors.textHint)),
        items: list
            .map((p) => DropdownMenuItem(
                  value: p,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                          child: Text(p.name, overflow: TextOverflow.ellipsis)),
                      if (p.isGalaxy)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.star,
                              size: 12, color: AppColors.secondary),
                        ),
                    ],
                  ),
                ))
            .toList(),
        onChanged: (val) => setState(() {
          item.product = val;
          item.rate = val?.defaultPrice ?? 0;
          if (!item.supports10Kg && item.bags10 > 0) {
            item.bags10 = 0;
            _bumpInputRevision('${item.hashCode}_bags10');
          }
          if (!item.supports5Kg && item.bags5 > 0) {
            item.bags5 = 0;
            _bumpInputRevision('${item.hashCode}_bags5');
          }
          _bumpInputRevision('${item.hashCode}_rate');
        }),
      ),
    );
  }

  Widget _bagInput(String label, int value, ValueChanged<String> onChanged,
      {required String fieldKey}) {
    return Expanded(
      child: TextFormField(
        key: ValueKey('$fieldKey:${_inputFieldRevisions[fieldKey] ?? 0}'),
        initialValue: value == 0 ? '' : value.toString(),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          hintText: label,
          hintStyle: const TextStyle(fontSize: 10, color: AppColors.textHint),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _disabledBagInput(String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
      ),
    );
  }

  int _parseNonNegativeInt(String input) =>
      math.max(0, int.tryParse(input) ?? 0);
  double _parseNonNegativeDouble(String input) =>
      math.max(0.0, double.tryParse(input) ?? 0.0);

  // ── Float safety helpers (prevent 119.999999 display issues) ─────────────
  static String _safeQtl(double v) {
    // Round to 3 dp then format to 2 dp to eliminate floating-point noise
    final rounded = (v * 1000).roundToDouble() / 1000;
    return rounded.toStringAsFixed(2);
  }

  static String _safeAmt(double v) {
    // Round to nearest rupee for display
    return v.roundToDouble().toStringAsFixed(0);
  }

  // ── STEP 4: Review ──────────────────────────────────────────────────────

  Widget _buildStep4Review() {
    final validCustomers = _customers.where((c) => c.isValid).toList();
    final settings = ref.watch(settingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...validCustomers.map((c) => _buildReviewCustomerCard(c, settings)),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _summaryRow(
                  'Order Date', DateFormat('dd MMM yyyy').format(_loadingDate)),
              const Divider(height: 16),
              _summaryRow('Total Customers', '${validCustomers.length}'),
              const Divider(height: 16),
              _summaryRow(
                  'Total Weight', '${_totalQtl.toStringAsFixed(2)} QTL'),
              const Divider(height: 16),
              // Effective Base = rate + packing surcharge (after bulk discount)
              _summaryRow('Effective Base',
                  '${settings.currencySymbol}${validCustomers.fold(0.0, (sum, c) => sum + c.items.where((i) => i.isValid).fold(0.0, (s, i) => s + i.baseAmount)).toStringAsFixed(2)}'),
              const Divider(height: 8),
              // AMC on all bag types (26kg + 10kg + 5kg)
              _summaryRow('Total AMC (1%)',
                  '${settings.currencySymbol}${validCustomers.fold(0.0, (sum, c) => sum + c.items.where((i) => i.isValid).fold(0.0, (s, i) => s + i.amcAmount)).toStringAsFixed(2)}'),
              const Divider(height: 8),
              _summaryRow('Total GST',
                  '${settings.currencySymbol}${validCustomers.fold(0.0, (sum, c) => sum + c.items.where((i) => i.isValid).fold(0.0, (s, i) => s + i.gstAmount)).toStringAsFixed(2)}'),
              const Divider(height: 16),
              _summaryRow('Grand Total',
                  '${settings.currencySymbol}${_totalAmount.toStringAsFixed(2)}',
                  isTotal: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCustomerCard(
      CustomerLoadFormData data, AppSettings settings) {
    final cc = settings.currencySymbol;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(data.customer?.shopName ?? 'Unknown',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.primary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('${data.totalQtl.toStringAsFixed(2)} QTL',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          ...data.items.where((i) => i.isValid).toList().asMap().entries.map(
              (entry) {
            final i = entry.value;
            final itemTotal = i.netAmount;
            final itemBase = i.baseAmount; // effective base (packing included)
            final itemAmc  = i.amcAmount;
            final itemGst  = i.gstAmount;
            // Show effective rate per-QTL for each bag type
            final has10or5 = i.applicableBags10 > 0 || i.applicableBags5 > 0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(i.product?.name ?? '-',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis)),
                        Text('$cc${itemTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: [
                        if (i.bags26 > 0) _reviewChip('${i.bags26}×26kg'),
                        if (i.applicableBags10 > 0) _reviewChip('${i.applicableBags10}×10kg'),
                        if (i.applicableBags5 > 0) _reviewChip('${i.applicableBags5}×5kg'),
                        _reviewChip('${_safeQtl(i.qtlTotal)} QTL'),
                        // Show effective rate (base + packing baked in)
                        if (has10or5)
                          _reviewChip('$cc${i.weightedEffectiveRate.toStringAsFixed(0)}/QTL (eff.)')
                        else
                          _reviewChip('$cc${i.rate.toStringAsFixed(0)}/QTL'),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Breakdown: Eff.Base already includes packing
                    Text(
                        'Eff. Base: $cc${itemBase.toStringAsFixed(0)}'
                        ' · AMC(1%): $cc${itemAmc.toStringAsFixed(0)}'
                        '${itemGst > 0 ? ' · GST: $cc${itemGst.toStringAsFixed(0)}' : ''}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                        softWrap: true),
                  ],
                ),
              ),
            );
          }),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Customer Total',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                Flexible(
                  child: Text('${data.totalQtl.toStringAsFixed(2)} QTL',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text('$cc${data.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 10, color: AppColors.primary)),
    );
  }

  Widget _summaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label,
              style: TextStyle(
                  fontSize: isTotal ? 15 : 13,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w400,
                  color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(value,
              style: TextStyle(
                  fontSize: isTotal ? 15 : 13,
                  fontWeight: FontWeight.bold,
                  color: isTotal ? AppColors.primary : AppColors.textPrimary),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
        ),
      ],
    );
  }

  Widget _buildStep5ExportShare() {
    final settings = ref.watch(settingsProvider);
    final orderNumber = _orderNumberController.text.trim().isEmpty
        ? (_orderNumber ?? '-')
        : _orderNumberController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStep4Review(),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.ios_share_outlined,
                      color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Export + Share',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _summaryRow(
                'Excel destination',
                settings.excelSavePath.isEmpty
                    ? 'App documents / Downloads'
                    : settings.excelSavePath,
              ),
              const Divider(height: 18),
              _summaryRow('Mill contact', settings.millContactPhone),
              const Divider(height: 18),
              _summaryRow('Order number', orderNumber),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _goToStep(_currentStep - 1),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: _isSaving
                  ? const Center(
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : FilledButton.icon(
                      onPressed: _saveLorryOrder,
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Save & Send'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  // ── BOTTOM BAR ──────────────────────────────────────────────────────────

  Widget? _buildBottomBar() {
    if (_currentStep == _totalSteps) return null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CapacityProgressCard(
                  currentQtl: _totalQtl,
                  maxCapacity: _capacity,
                  label: 'Lorry Fill Progress'),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  if (_currentStep > 1)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _goToStep(_currentStep - 1),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 1) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => _goToStep(_currentStep + 1),
                      icon: Icon(
                          _currentStep == _totalSteps - 1
                              ? Icons.ios_share_outlined
                              : Icons.arrow_forward,
                          size: 18),
                      label: Text(_currentStep == _totalSteps - 1
                          ? 'Export & Share'
                          : 'Next'),
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
}
