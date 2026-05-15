import 'package:flutter_test/flutter_test.dart';
import 'package:rice_agent/db/database.dart';
import 'package:rice_agent/screens/new_order_screen.dart';

// ---------------------------------------------------------------------------
// Helper to build a Product quickly
// ---------------------------------------------------------------------------
Product makeProduct({
  String id = '1',
  String name = 'Test Rice',
  double price = 5000,
  double gst = 0.0,
  String unit = 'qtl',
  String? sku,
  bool isGalaxy = false,
}) =>
    Product(
      id: id,
      name: name,
      defaultPrice: price,
      gstRateDefault: gst,
      unit: unit,
      sku: sku,
      isGalaxy: isGalaxy,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------
final productNoGst = makeProduct(id: '1', gst: 0.0, unit: 'qtl');
final productGst5 = makeProduct(id: '2', gst: 5.0, unit: 'qtl');

// Product that supports only 10kg bags (p10:1, p5:0)
final productOnly10kg =
    makeProduct(id: '3', unit: 'qtl|p10:1|p5:0', gst: 5.0);

// Product that supports only 5kg bags (p10:0, p5:1)
final productOnly5kg =
    makeProduct(id: '4', unit: 'qtl|p10:0|p5:1', gst: 5.0);

// Product with no pack support at all (p10:0, p5:0)
final productNoPacks =
    makeProduct(id: '5', unit: 'qtl|p10:0|p5:0', gst: 0.0);

void main() {
  // =========================================================================
  // GROUP 1 – Weight Calculations
  // =========================================================================
  group('OrderItemFormData - Weight Calculations', () {
    test('26kg bags only', () {
      final item =
          OrderItemFormData(product: productNoGst, bags26: 10, rate: 5000);
      expect(item.kg26, 260.0);
      expect(item.kg10, 0.0);
      expect(item.kg5, 0.0);
      expect(item.kgTotal, 260.0);
      expect(item.qtlTotal, 2.6);
    });

    test('10kg bags only', () {
      final item =
          OrderItemFormData(product: productNoGst, bags10: 20, rate: 5000);
      expect(item.kg10, 200.0);
      expect(item.kgTotal, 200.0);
      expect(item.qtlTotal, 2.0);
    });

    test('5kg bags only', () {
      final item =
          OrderItemFormData(product: productNoGst, bags5: 40, rate: 5000);
      expect(item.kg5, 200.0);
      expect(item.kgTotal, 200.0);
      expect(item.qtlTotal, 2.0);
    });

    test('mixed bags weight', () {
      final item = OrderItemFormData(
          product: productNoGst, bags26: 10, bags10: 10, bags5: 10, rate: 5000);
      expect(item.kgTotal, 410.0); // 260+100+50
      expect(item.qtlTotal, 4.1);
    });

    test('zero bags gives zero weight', () {
      final item = OrderItemFormData(product: productNoGst, rate: 5000);
      expect(item.kgTotal, 0.0);
      expect(item.qtlTotal, 0.0);
    });
  });

  // =========================================================================
  // GROUP 2 – 26kg Logic (No Packing, No GST, 1% AMC)
  // =========================================================================
  group('OrderItemFormData - 26kg Logic', () {
    test('basic 100 bags at ₹5000/qtl', () {
      final item = OrderItemFormData(
          product: productNoGst, bags26: 100, rate: 5000);
      // value: (5000/100)*26*100 = 130000
      expect(item.value26, 130000.0);
      expect(item.amc26, 1300.0); // 1%
      expect(item.total26, 131300.0);
      expect(item.netAmount, 131300.0);
      expect(item.gstAmount, 0.0);
    });

    test('1 bag at ₹5000/qtl', () {
      final item =
          OrderItemFormData(product: productNoGst, bags26: 1, rate: 5000);
      // (5000/100)*26*1 = 1300
      expect(item.value26, 1300.0);
      expect(item.amc26, 13.0);
      expect(item.total26, 1313.0);
    });

    test('26kg bags with GST product still gets no GST (26kg is exempted)', () {
      final item =
          OrderItemFormData(product: productGst5, bags26: 10, rate: 5000);
      expect(item.gst10, 0.0); // no 10kg bags
      expect(item.gst5, 0.0); // no 5kg bags
      expect(item.gstAmount, 0.0);
    });
  });

  // =========================================================================
  // GROUP 3 – 10kg Logic (Packing per Quintal, 1% AMC, 5% GST)
  // =========================================================================
  group('OrderItemFormData - 10kg Logic (packing per quintal)', () {
    // PACKING FORMULA: packingPrice10 * (bags10 * 10 / 100)
    // 10 bags × 10kg = 1.0 qtl → packing = ₹200 * 1.0 = ₹200
    test('10 bags at ₹5000/qtl with ₹200/qtl packing and 5% GST', () {
      final item = OrderItemFormData(
        product: productGst5,
        bags10: 10,
        rate: 5000,
        packingPrice10: 200.0,
      );
      // base = (5000/100)*10*10 = 5000
      expect(item.baseValue10, 5000.0);
      // packing = 200 * (10*10/100) = 200 * 1.0 = 200
      expect(item.packing10, 200.0);
      // subtotal = 5000+200 = 5200
      expect(item.subtotal10, 5200.0);
      // AMC 1%: 5200*0.01 = 52
      expect(item.amc10, 52.0);
      // GST 5%: (5200+52)*0.05 = 5252*0.05 = 262.6
      expect(item.gst10, 262.6);
      // total = 5200+52+262.6 = 5514.6
      expect(item.total10, 5514.6);
    });

    test('5 bags at ₹5000/qtl – 0.5 qtl packing', () {
      final item = OrderItemFormData(
        product: productGst5,
        bags10: 5,
        rate: 5000,
        packingPrice10: 200.0,
      );
      // packing = 200 * (5*10/100) = 200*0.5 = 100
      expect(item.packing10, 100.0);
    });

    test('no GST on 10kg when product has 0% GST', () {
      final item = OrderItemFormData(
        product: productNoGst,
        bags10: 10,
        rate: 5000,
        packingPrice10: 200.0,
      );
      expect(item.gst10, 0.0);
    });

    test('packing scales linearly with quantity', () {
      final item20 = OrderItemFormData(
        product: productGst5,
        bags10: 20,
        rate: 5000,
        packingPrice10: 200.0,
      );
      final item10 = OrderItemFormData(
        product: productGst5,
        bags10: 10,
        rate: 5000,
        packingPrice10: 200.0,
      );
      // packing for 20 bags should be 2× that of 10 bags
      expect(item20.packing10, item10.packing10 * 2);
    });
  });

  // =========================================================================
  // GROUP 4 – 5kg Logic (Packing per Quintal, 1% AMC, 5% GST)
  // =========================================================================
  group('OrderItemFormData - 5kg Logic (packing per quintal)', () {
    // 20 bags × 5kg = 1.0 qtl → packing = ₹250 * 1.0 = ₹250
    test('20 bags at ₹5000/qtl with ₹250/qtl packing and 5% GST', () {
      final item = OrderItemFormData(
        product: productGst5,
        bags5: 20,
        rate: 5000,
        packingPrice5: 250.0,
      );
      // base = (5000/100)*5*20 = 5000
      expect(item.baseValue5, 5000.0);
      // packing = 250 * (20*5/100) = 250 * 1.0 = 250
      expect(item.packing5, 250.0);
      // subtotal = 5000+250 = 5250
      expect(item.subtotal5, 5250.0);
      // AMC 1%: 5250*0.01 = 52.5
      expect(item.amc5, 52.5);
      // GST 5%: (5250+52.5)*0.05 = 5302.5*0.05 = 265.125
      expect(item.gst5, closeTo(265.125, 0.001));
      // total = 5250+52.5+265.125 = 5567.625
      expect(item.total5, closeTo(5567.625, 0.001));
    });

    test('10 bags (0.5 qtl) packing', () {
      final item = OrderItemFormData(
        product: productGst5,
        bags5: 10,
        rate: 5000,
        packingPrice5: 250.0,
      );
      // packing = 250 * (10*5/100) = 250 * 0.5 = 125
      expect(item.packing5, 125.0);
    });

    test('no GST on 5kg when product has 0% GST', () {
      final item = OrderItemFormData(
        product: productNoGst,
        bags5: 20,
        rate: 5000,
        packingPrice5: 250.0,
      );
      expect(item.gst5, 0.0);
    });
  });

  // =========================================================================
  // GROUP 5 – Mixed Bags
  // =========================================================================
  group('OrderItemFormData - Mixed Bags', () {
    test('net = total26 + total10 + total5', () {
      final item = OrderItemFormData(
        product: productGst5,
        bags26: 10,
        bags10: 10,
        bags5: 20,
        rate: 5000,
        packingPrice10: 200.0,
        packingPrice5: 250.0,
      );
      expect(item.netAmount,
          closeTo(item.total26 + item.total10 + item.total5, 0.001));
    });

    test('amcAmount = amc26 + amc10 + amc5', () {
      final item = OrderItemFormData(
        product: productGst5,
        bags26: 5,
        bags10: 5,
        bags5: 10,
        rate: 5000,
        packingPrice10: 200.0,
        packingPrice5: 250.0,
      );
      expect(item.amcAmount,
          closeTo(item.amc26 + item.amc10 + item.amc5, 0.001));
    });

    test('gstAmount = gst10 + gst5 only (26kg is GST-free)', () {
      final item = OrderItemFormData(
        product: productGst5,
        bags26: 10,
        bags10: 10,
        bags5: 10,
        rate: 5000,
      );
      expect(item.gstAmount, closeTo(item.gst10 + item.gst5, 0.001));
    });

    test('baseAmount = value26 + baseValue10 + baseValue5', () {
      final item = OrderItemFormData(
        product: productGst5,
        bags26: 4,
        bags10: 4,
        bags5: 4,
        rate: 5000,
      );
      expect(item.baseAmount,
          closeTo(item.value26 + item.baseValue10 + item.baseValue5, 0.001));
    });
  });

  // =========================================================================
  // GROUP 6 – Unit-Flag Pack Support (_supportsPackFromUnit)
  // =========================================================================
  group('OrderItemFormData - Unit Flag Pack Support', () {
    test('product with unit=qtl supports both 10kg and 5kg', () {
      final item = OrderItemFormData(
          product: productNoGst, bags10: 5, bags5: 5, rate: 5000);
      expect(item.supports10Kg, true);
      expect(item.supports5Kg, true);
      expect(item.applicableBags10, 5);
      expect(item.applicableBags5, 5);
    });

    test('product with p10:0 excludes 10kg bags from calculation', () {
      final item = OrderItemFormData(
          product: productOnly5kg, bags10: 10, bags5: 10, rate: 5000);
      expect(item.supports10Kg, false);
      expect(item.supports5Kg, true);
      expect(item.applicableBags10, 0);
      expect(item.applicableBags5, 10);
      // 10kg packing should be 0 since not supported
      expect(item.packing10, 0.0);
    });

    test('product with p5:0 excludes 5kg bags from calculation', () {
      final item = OrderItemFormData(
          product: productOnly10kg, bags10: 10, bags5: 10, rate: 5000);
      expect(item.supports5Kg, false);
      expect(item.supports10Kg, true);
      expect(item.applicableBags5, 0);
      expect(item.applicableBags10, 10);
      // 5kg packing should be 0
      expect(item.packing5, 0.0);
    });

    test('product with p10:0 and p5:0 – only 26kg counts', () {
      final item = OrderItemFormData(
          product: productNoPacks,
          bags26: 10,
          bags10: 10,
          bags5: 10,
          rate: 5000);
      expect(item.applicableBags10, 0);
      expect(item.applicableBags5, 0);
      expect(item.kgTotal, 260.0); // only 26kg counts
      expect(item.packing10, 0.0);
      expect(item.packing5, 0.0);
    });

    test('null unit string defaults to supporting all packs', () {
      final item = OrderItemFormData(
          product: makeProduct(unit: ''),
          bags10: 5,
          bags5: 5,
          rate: 5000);
      expect(item.supports10Kg, true);
      expect(item.supports5Kg, true);
    });
  });

  // =========================================================================
  // GROUP 7 – isValid Logic
  // =========================================================================
  group('OrderItemFormData - isValid', () {
    test('valid: product + bags26 + rate > 0', () {
      final item = OrderItemFormData(
          product: productNoGst, bags26: 1, rate: 5000);
      expect(item.isValid, true);
    });

    test('valid: only 10kg bags', () {
      final item = OrderItemFormData(
          product: productGst5, bags10: 1, rate: 5000);
      expect(item.isValid, true);
    });

    test('valid: only 5kg bags', () {
      final item = OrderItemFormData(
          product: productGst5, bags5: 1, rate: 5000);
      expect(item.isValid, true);
    });

    test('invalid: no product', () {
      final item = OrderItemFormData(bags26: 10, rate: 5000);
      expect(item.isValid, false);
    });

    test('invalid: all bags = 0', () {
      final item =
          OrderItemFormData(product: productNoGst, bags26: 0, rate: 5000);
      expect(item.isValid, false);
    });

    test('invalid: rate = 0', () {
      final item = OrderItemFormData(product: productNoGst, bags26: 10, rate: 0);
      expect(item.isValid, false);
    });

    test('invalid: product that rejects 10kg and 5kg with only those bags', () {
      // productNoPacks: p10:0 p5:0 – applicableBags for both is 0
      final item = OrderItemFormData(
          product: productNoPacks, bags10: 5, bags5: 5, rate: 5000);
      // No applicable bags → isValid false (bags26>0 || applicable10>0 || applicable5>0)
      expect(item.applicableBags10, 0);
      expect(item.applicableBags5, 0);
      expect(item.isValid, false);
    });
  });

  // =========================================================================
  // GROUP 8 – amcPercent / gstPercent helpers
  // =========================================================================
  group('OrderItemFormData - Percentage Helpers', () {
    test('amcPercent is always 1.0', () {
      final item =
          OrderItemFormData(product: productGst5, bags26: 10, rate: 5000);
      expect(item.amcPercent, 1.0);
    });

    test('gstPercent is 0 when no taxable bags', () {
      final item =
          OrderItemFormData(product: productNoGst, bags26: 10, rate: 5000);
      expect(item.gstPercent, 0.0);
    });

    test('gstPercent is approximately 5 for gst5 product with 10kg bags', () {
      final item =
          OrderItemFormData(product: productGst5, bags10: 10, rate: 5000);
      // gstPercent = gstAmount / taxableSubtotal * 100 ≈ 5%
      expect(item.gstPercent, closeTo(5.0, 0.001));
    });
  });

  // =========================================================================
  // GROUP 9 – Edge Cases
  // =========================================================================
  group('OrderItemFormData - Edge Cases', () {
    test('rate = 0 → all amounts are 0', () {
      final item = OrderItemFormData(
          product: productGst5, bags26: 10, bags10: 10, bags5: 10, rate: 0);
      expect(item.value26, 0.0);
      expect(item.baseValue10, 0.0);
      expect(item.baseValue5, 0.0);
      // packing is based on qty not rate, so it is non-zero
      expect(item.packing10, greaterThan(0));
      expect(item.netAmount.isFinite, true);
      expect(item.isValid, false);
    });

    test('very large quantity does not overflow', () {
      final item =
          OrderItemFormData(product: productNoGst, bags26: 10000, rate: 10000);
      expect(item.kgTotal, 260000.0);
      expect(item.netAmount.isFinite, true);
    });

    test('very large packing price', () {
      final item = OrderItemFormData(
        product: productGst5,
        bags10: 100,
        rate: 5000,
        packingPrice10: 9999.0,
      );
      expect(item.packing10.isFinite, true);
      expect(item.netAmount.isFinite, true);
    });

    test('decimal rate values compute correctly', () {
      final item = OrderItemFormData(
          product: productNoGst, bags26: 1, rate: 5500.50);
      // (5500.5/100)*26 = 1430.13
      expect(item.value26, closeTo(1430.13, 0.01));
      expect(item.netAmount.isFinite, true);
    });

    test('packing price = 0 gives zero packing cost', () {
      final item = OrderItemFormData(
        product: productGst5,
        bags10: 10,
        bags5: 10,
        rate: 5000,
        packingPrice10: 0.0,
        packingPrice5: 0.0,
      );
      expect(item.packing10, 0.0);
      expect(item.packing5, 0.0);
    });

    test('zero bags of one type does not affect other types', () {
      final item26only = OrderItemFormData(
          product: productNoGst, bags26: 5, bags10: 0, bags5: 0, rate: 5000);
      final item10only = OrderItemFormData(
          product: productNoGst, bags26: 0, bags10: 5, bags5: 0, rate: 5000);
      // They should not be equal
      expect(item26only.netAmount, isNot(equals(item10only.netAmount)));
    });
  });

  // =========================================================================
  // GROUP 10 – CustomerLoadFormData
  // =========================================================================
  group('CustomerLoadFormData', () {
    final customer = Customer(
      id: 'c1',
      shopName: 'Test Shop',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    test('isValid true when customer + at least one valid item', () {
      final load = CustomerLoadFormData(
        customer: customer,
        items: [
          OrderItemFormData(product: productNoGst, bags26: 5, rate: 5000)
        ],
      );
      expect(load.isValid, true);
    });

    test('isValid false when customer is null', () {
      final load = CustomerLoadFormData(
        customer: null,
        items: [
          OrderItemFormData(product: productNoGst, bags26: 5, rate: 5000)
        ],
      );
      expect(load.isValid, false);
    });

    test('isValid false when all items are invalid', () {
      final load = CustomerLoadFormData(
        customer: customer,
        items: [
          OrderItemFormData(product: null, bags26: 5, rate: 5000),
          OrderItemFormData(product: productNoGst, bags26: 0, rate: 0),
        ],
      );
      expect(load.isValid, false);
    });

    test('totalQtl sums only valid items', () {
      final validItem =
          OrderItemFormData(product: productNoGst, bags26: 10, rate: 5000);
      final invalidItem = OrderItemFormData(product: null, bags26: 5, rate: 0);
      final load = CustomerLoadFormData(
        customer: customer,
        items: [validItem, invalidItem],
      );
      expect(load.totalQtl, validItem.qtlTotal);
    });

    test('totalAmount sums only valid items', () {
      final validItem =
          OrderItemFormData(product: productGst5, bags10: 10, rate: 5000);
      final invalidItem =
          OrderItemFormData(product: null, bags26: 10, rate: 5000);
      final load = CustomerLoadFormData(
        customer: customer,
        items: [validItem, invalidItem],
      );
      expect(load.totalAmount, closeTo(validItem.netAmount, 0.001));
    });

    test('totalAmount and totalQtl are 0 when items list is empty', () {
      final load =
          CustomerLoadFormData(customer: customer, items: []);
      expect(load.totalQtl, 0.0);
      expect(load.totalAmount, 0.0);
      expect(load.isValid, false);
    });

    test('multiple valid items accumulate correctly', () {
      final item1 =
          OrderItemFormData(product: productNoGst, bags26: 5, rate: 5000);
      final item2 =
          OrderItemFormData(product: productGst5, bags10: 10, rate: 4500);
      final load =
          CustomerLoadFormData(customer: customer, items: [item1, item2]);
      expect(load.totalQtl,
          closeTo(item1.qtlTotal + item2.qtlTotal, 0.001));
      expect(load.totalAmount,
          closeTo(item1.netAmount + item2.netAmount, 0.001));
    });
  });

  // =========================================================================
  // GROUP 11 – Packing Per-Quintal Formula Regression
  // (Ensures the old per-bag math never creeps back)
  // =========================================================================
  group('Packing Per-Quintal Regression', () {
    // For 10 bags of 10kg = 1 qtl
    // OLD (wrong): 200 * 10 bags = 2000
    // NEW (correct): 200 * (10*10/100) = 200 * 1.0 = 200
    test('10kg packing is per-quintal NOT per-bag', () {
      final item = OrderItemFormData(
          product: productGst5, bags10: 10, rate: 5000, packingPrice10: 200.0);
      expect(item.packing10, 200.0); // not 2000
      expect(item.packing10, isNot(2000.0));
    });

    // For 20 bags of 5kg = 1 qtl
    // OLD (wrong): 250 * 20 bags = 5000
    // NEW (correct): 250 * (20*5/100) = 250 * 1.0 = 250
    test('5kg packing is per-quintal NOT per-bag', () {
      final item = OrderItemFormData(
          product: productGst5, bags5: 20, rate: 5000, packingPrice5: 250.0);
      expect(item.packing5, 250.0); // not 5000
      expect(item.packing5, isNot(5000.0));
    });

    test('packing for 2 qtl of 10kg bags = 2 × packing rate', () {
      // 2 qtl = 200kg = 20 bags of 10kg
      final item = OrderItemFormData(
          product: productGst5, bags10: 20, rate: 5000, packingPrice10: 200.0);
      expect(item.packing10, 400.0); // 200 * 2 qtl
    });

    test('packing for 2 qtl of 5kg bags = 2 × packing rate', () {
      // 2 qtl = 200kg = 40 bags of 5kg
      final item = OrderItemFormData(
          product: productGst5, bags5: 40, rate: 5000, packingPrice5: 250.0);
      expect(item.packing5, 500.0); // 250 * 2 qtl
    });
  });
}
