import 'package:drift/drift.dart';
import '../db/database.dart';
import '../providers/settings_provider.dart';

class ProductSeedingService {
  static Future<void> seedInitialProducts(AppDatabase db) async {
    final count = await db.select(db.products).get();
    if (count.isNotEmpty) return; // Only seed if empty

    final products = [
      {'name': 'HMT GREEN GALAXY CLOTH', 'price': 5400.0, 'pack10': true, 'pack5': true},
      {'name': 'HMT BLUE GALAXY', 'price': 4900.0, 'pack10': false, 'pack5': false},
      {'name': 'HMT ORANGE AMARAVATHI CLOTH', 'price': 4900.0, 'pack10': false, 'pack5': false},
      {'name': 'JEERA COPPER', 'price': 4900.0, 'pack10': true, 'pack5': true},
      {'name': 'HMT GOLD CROP', 'price': 0.0, 'pack10': false, 'pack5': false},
      {'name': 'BPT BLUE GALAXY', 'price': 4500.0, 'pack10': true, 'pack5': true},
      {'name': 'BPT RED GALAXY', 'price': 4400.0, 'pack10': true, 'pack5': true},
      {'name': 'BPT ORANGE GOLD', 'price': 4400.0, 'pack10': false, 'pack5': false},
      {'name': 'BPT GOLD CROP', 'price': 4150.0, 'pack10': false, 'pack5': false},
      {'name': 'BROWN RICE', 'price': 5150.0, 'pack10': true, 'pack5': true},
      {'name': 'OLD BPT RAW RICE', 'price': 4950.0, 'pack10': false, 'pack5': false},
      {'name': 'RGL', 'price': 4050.0, 'pack10': false, 'pack5': false},
      {'name': 'KARTHIKA BLUE', 'price': 0.0, 'pack10': false, 'pack5': false},
      {'name': 'KARTHIKA BROWN', 'price': 0.0, 'pack10': false, 'pack5': false},
      {'name': 'THICK GRADER TEJA', 'price': 3750.0, 'pack10': false, 'pack5': false},
    ];

    await db.batch((batch) {
      for (int i = 0; i < products.length; i++) {
        final p = products[i];
        batch.insert(
            db.products,
            _p(
                p['name'] as String,
                p['price'] as double,
                p['pack10'] as bool,
                p['pack5'] as bool));
      }
    });
  }

  static bool _isExcludedFromDiscount(String name) {
    final upper = name.toUpperCase();
    return upper == 'KARTHIKA BLUE' || upper == 'KARTHIKA BROWN' || upper == 'RGL';
  }

  static ProductsCompanion _p(
      String name, double price, bool pack10, bool pack5) {
    
    String unitMeta = 'qtl|p10:${pack10 ? 1 : 0}|p5:${pack5 ? 1 : 0}';
    bool isGalaxy = !_isExcludedFromDiscount(name);

    return ProductsCompanion.insert(
      id: generateId(),
      name: name,
      defaultPrice: price,
      gstRateDefault: const Value(0.0),
      unit: Value(unitMeta),
      isGalaxy: Value(isGalaxy),
      updatedAt: DateTime.now(),
    );


  }
}
