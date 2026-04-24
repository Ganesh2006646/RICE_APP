import 'package:drift/drift.dart';
import '../db/database.dart';
import '../providers/settings_provider.dart';

class ProductSeedingService {
  static Future<void> seedInitialProducts(AppDatabase db) async {
    final count = await db.select(db.products).get();
    if (count.isNotEmpty) return; // Only seed if empty

    final products = [
      {'name': 'Galaxy Sona Rice', 'price': 4800.0, 'gst': 0.0},
      {'name': 'Raw Non Basmati Rice', 'price': 5200.0, 'gst': 0.0},
      {'name': 'Non Basmati Parboiled Rice', 'price': 4800.0, 'gst': 0.0},
      {'name': 'Raw Broken Rice', 'price': 3200.0, 'gst': 0.0},
    ];

    await db.batch((batch) {
      for (int i = 0; i < products.length; i++) {
        final p = products[i];
        batch.insert(
            db.products,
            _p(p['name'] as String, p['price'] as double, p['gst'] as double,
                i));
      }
    });
  }

  static ProductsCompanion _p(
      String name, double price, double gst, int index) {
    return ProductsCompanion.insert(
      id: generateId(),
      name: name,
      defaultPrice: price,
      gstRateDefault: Value(gst),
      updatedAt: DateTime.now(),
    );
  }
}
