import 'package:flutter_test/flutter_test.dart';
import 'package:rice_agent/db/database.dart';
import 'package:rice_agent/screens/new_order_screen.dart';

void main() {
  // Test product fixture
  final testProduct = Product(
    id: '1',
    name: 'Test Rice',
    defaultPrice: 5000,
    gstRateDefault: 0.0,
    unit: 'qtl',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    sku: 'TEST-001',
  );

  final testProductWithGst5 = Product(
    id: '2',
    name: 'Test Rice GST',
    defaultPrice: 5000,
    gstRateDefault: 5.0,
    unit: 'qtl',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    sku: 'TEST-002',
  );

  group('OrderItemFormData - Weight Calculations', () {
    test('calculates weight correctly for 26kg bags only', () {
      final item = OrderItemFormData(
        product: testProduct,
        bags26: 10,
        bags10: 0,
        bags5: 0,
        rate: 5000,
      );

      expect(item.kg26, 260.0); // 10 * 26
      expect(item.kg10, 0.0);
      expect(item.kg5, 0.0);
      expect(item.kgTotal, 260.0);
      expect(item.qtlTotal, 2.6); // 260 / 100
    });

    test('calculates weight correctly for 10kg bags only', () {
      final item = OrderItemFormData(
        product: testProduct,
        bags26: 0,
        bags10: 20,
        bags5: 0,
        rate: 5000,
      );

      expect(item.kg10, 200.0); // 20 * 10
      expect(item.kgTotal, 200.0);
      expect(item.qtlTotal, 2.0);
    });

    test('calculates weight correctly for 5kg bags only', () {
      final item = OrderItemFormData(
        product: testProduct,
        bags26: 0,
        bags10: 0,
        bags5: 40,
        rate: 5000,
      );

      expect(item.kg5, 200.0); // 40 * 5
      expect(item.kgTotal, 200.0);
      expect(item.qtlTotal, 2.0);
    });

    test('calculates weight correctly for mixed bags', () {
      final item = OrderItemFormData(
        product: testProduct,
        bags26: 10, // 260 kg
        bags10: 10, // 100 kg
        bags5: 10, // 50 kg
        rate: 5000,
      );

      expect(item.kgTotal, 410.0); // 260 + 100 + 50
      expect(item.qtlTotal, 4.1);
    });
  });

  group('OrderItemFormData - 26kg Bags (No GST, 1% AMC)', () {
    test('calculates correctly for 26kg bags - basic scenario', () {
      final item = OrderItemFormData(
        product: testProduct,
        bags26: 100,
        bags10: 0,
        bags5: 0,
        rate: 5000, // ₹5000 per 100kg (quintal)
      );

      // Base value: (5000/100) * 26 * 100 = 130,000
      expect(item.value26, 130000.0);

      // AMC 1%: 130000 * 0.01 = 1300
      expect(item.amc26, 1300.0);

      // Total 26kg = value + AMC = 131300
      expect(item.total26, 131300.0);

      // NetAmount should equal total26 when only 26kg bags
      expect(item.netAmount, 131300.0);

      // No GST on 26kg bags
      expect(item.gst10, 0.0);
      expect(item.gst5, 0.0);
      expect(item.gstAmount, 0.0);
    });
  });

  group('OrderItemFormData - 10kg Bags (₹200 Packing, 1% AMC, 5% GST)', () {
    test('calculates correctly for 10kg bags with packing and GST', () {
      final item = OrderItemFormData(
        product: testProductWithGst5,
        bags26: 0,
        bags10: 10,
        bags5: 0,
        rate: 5000, // ₹5000 per quintal
      );

      // Base value: (5000/100) * 10 * 10 = 5000
      expect(item.baseValue10, 5000.0);

      // Packing: ₹200 * 10 bags = 2000
      expect(item.packing10, 2000.0);

      // Subtotal10: 5000 + 2000 = 7000
      expect(item.subtotal10, 7000.0);

      // AMC 1%: 7000 * 0.01 = 70
      expect(item.amc10, 70.0);

      // GST 5% of (subtotal + AMC): (7000 + 70) * 0.05 = 353.5
      expect(item.gst10, 353.5);

      // Total 10kg = 7000 + 70 + 353.5 = 7423.5
      expect(item.total10, 7423.5);
    });
  });

  group('OrderItemFormData - 5kg Bags (₹250 Packing, 1% AMC, 5% GST)', () {
    test('calculates correctly for 5kg bags with packing and GST', () {
      final item = OrderItemFormData(
        product: testProductWithGst5,
        bags26: 0,
        bags10: 0,
        bags5: 20,
        rate: 5000, // ₹5000 per quintal
      );

      // Base value: (5000/100) * 5 * 20 = 5000
      expect(item.baseValue5, 5000.0);

      // Packing: ₹250 * 20 bags = 5000
      expect(item.packing5, 5000.0);

      // Subtotal5: 5000 + 5000 = 10000
      expect(item.subtotal5, 10000.0);

      // AMC 1%: 10000 * 0.01 = 100
      expect(item.amc5, 100.0);

      // GST 5% of (subtotal + AMC): (10000 + 100) * 0.05 = 505
      expect(item.gst5, 505.0);

      // Total 5kg = 10000 + 100 + 505 = 10605
      expect(item.total5, 10605.0);
    });
  });

  group('OrderItemFormData - Mixed Bags Scenario', () {
    test('calculates correctly for all bag types combined', () {
      final item = OrderItemFormData(
        product: testProduct,
        bags26: 10, // 260 kg
        bags10: 10, // 100 kg
        bags5: 10, // 50 kg
        rate: 5000,
      );

      // Verify weights
      expect(item.kgTotal, 410.0);
      expect(item.qtlTotal, 4.1);

      // Net should be sum of all three totals
      expect(item.netAmount, item.total26 + item.total10 + item.total5);

      // AMC should be sum of all three
      expect(item.amcAmount, item.amc26 + item.amc10 + item.amc5);

      // GST should be sum of 10kg and 5kg GST only
      expect(item.gstAmount, item.gst10 + item.gst5);
    });
  });

  group('OrderItemFormData - Validation', () {
    test('isValid returns false when product is null', () {
      final item = OrderItemFormData(
        product: null,
        bags26: 10,
        rate: 5000,
      );
      expect(item.isValid, false);
    });

    test('isValid returns false when no bags', () {
      final item = OrderItemFormData(
        product: testProduct,
        bags26: 0,
        bags10: 0,
        bags5: 0,
        rate: 5000,
      );
      expect(item.isValid, false);
    });

    test('isValid returns false when rate is 0', () {
      final item = OrderItemFormData(
        product: testProduct,
        bags26: 10,
        rate: 0,
      );
      expect(item.isValid, false);
    });

    test('isValid returns true for valid item', () {
      final item = OrderItemFormData(
        product: testProduct,
        bags26: 10,
        bags10: 0,
        bags5: 0,
        rate: 5000,
      );
      expect(item.isValid, true);
    });
  });

  group('OrderItemFormData - Edge Cases', () {
    test('handles zero rate correctly', () {
      final item = OrderItemFormData(
        product: testProduct,
        bags26: 10,
        rate: 0,
      );
      expect(item.netAmount, 0.0);
      expect(item.isValid, false);
    });

    test('handles very large quantities', () {
      final item = OrderItemFormData(
        product: testProduct,
        bags26: 1000,
        rate: 10000,
      );
      // Should not overflow
      expect(item.kgTotal, 26000.0);
      expect(item.qtlTotal, 260.0);
      expect(item.netAmount.isFinite, true);
    });

    test('handles decimal rate values', () {
      final item = OrderItemFormData(
        product: testProduct,
        bags26: 1,
        rate: 5500.50,
      );
      // Should handle decimals
      expect(item.value26.isFinite, true);
      expect(item.netAmount.isFinite, true);
    });
  });

  group('CustomerLoadFormData', () {
    test('calculates customer totals correctly', () {
      final customer = Customer(
        id: '1',
        shopName: 'Test Shop',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final items = [
        OrderItemFormData(product: testProduct, bags26: 10, rate: 5000),
        OrderItemFormData(product: testProduct, bags10: 10, rate: 5000),
      ];

      final customerLoad = CustomerLoadFormData(
        customer: customer,
        items: items,
      );

      // Both items are valid
      expect(customerLoad.isValid, true);

      // Total should be sum of both items
      expect(customerLoad.totalQtl, items[0].qtlTotal + items[1].qtlTotal);
      expect(customerLoad.totalAmount, items[0].netAmount + items[1].netAmount);
    });

    test('isValid returns false when customer is null', () {
      final items = [
        OrderItemFormData(product: testProduct, bags26: 10, rate: 5000),
      ];

      final customerLoad = CustomerLoadFormData(
        customer: null,
        items: items,
      );

      expect(customerLoad.isValid, false);
    });
  });
}
