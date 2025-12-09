import 'package:flutter_test/flutter_test.dart';
import 'package:rice_agent/db/database.dart';
import 'package:rice_agent/screens/new_order_wizard.dart';

void main() {
  group('OrderItemData Logic', () {
    final productNoTax = Product(
        id: '1',
        name: 'Rice 1',
        defaultPrice: 5000,
        gstRateDefault: 0.0,
        unit: 'qtl',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        sku: 'SKU1');

    test('Calculates qty and totals for 26kg bags (No Tax)', () {
      final item = OrderItemData(
        product: productNoTax,
        bags26: 100,
        ratePerQtl: 5000,
      );

      // 100 * 26 = 2600 kg
      expect(item.qtyKg, 2600.0);
      // 26.00 QTL
      expect(item.qtyQtl, 26.00);

      // Line Amount: 26.0 * 5000 = 130,000
      expect(item.lineAmount, 130000.0);

      // AMC 1%: 1300.0
      expect(item.amcAmount, 1300.0);

      // GST: 0% because bags10/5=0 and product default is 0
      expect(item.gstPercent, 0.0);
      expect(item.gstAmount, 0.0);

      // Net: 130000 + 1300 = 131300
      expect(item.netAmount, 131300.0);
    });

    test('Calculates qty and totals for mixed bags (Tax Triggered)', () {
      final item = OrderItemData(
        product: productNoTax, // Product stays 0%, but small bags trigger 5%
        bags26: 0,
        bags10: 10,
        bags5: 0,
        ratePerQtl: 4000,
      );

      // 10 * 10 = 100 kg = 1.0 QTL
      expect(item.qtyQtl, 1.0);

      // Line: 1.0 * 4000 = 4000
      expect(item.lineAmount, 4000.0);

      // AMC 1%: 40.0
      expect(item.amcAmount, 40.0);

      // GST should be 5% because bags10 > 0
      expect(item.gstPercent, 5.0);

      // Taxable amount = Line + AMC = 4040
      // GST 5% of 4040 = 202.0
      expect(item.gstAmount, 202.0);

      // Net: 4040 + 202 = 4242
      expect(item.netAmount, 4242.0);
    });
  });
}
