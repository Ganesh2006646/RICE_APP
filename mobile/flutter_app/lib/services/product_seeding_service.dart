import 'package:drift/drift.dart';
import '../db/database.dart';
import '../providers/settings_provider.dart';

class ProductSeedingService {
  static Future<void> seedInitialProducts(AppDatabase db) async {
    final count = await db.select(db.products).get();
    if (count.isNotEmpty) return; // Only seed if empty

    final products = [
      // EXEMPTED (0% GST)
      {'name': 'HMT GREEN GALAXY CLOTH', 'price': 5200.0, 'gst': 0.0},
      {'name': 'HMT BLUE GALAXY', 'price': 4800.0, 'gst': 0.0},
      {'name': 'HMT ORANGE AMARAVATHI CLOTH', 'price': 4800.0, 'gst': 0.0},
      {'name': 'JEERA COPPER', 'price': 4800.0, 'gst': 0.0},
      {'name': 'HMT GOLD CROP', 'price': 0.0, 'gst': 0.0},
      {'name': 'BPT BLUE GALAXY', 'price': 4300.0, 'gst': 0.0},
      {'name': 'BPT RED GALAXY', 'price': 4200.0, 'gst': 0.0},
      {'name': 'BPT ORANGE GOLD', 'price': 4200.0, 'gst': 0.0},
      {'name': 'BPT GOLD CROP', 'price': 4000.0, 'gst': 0.0},
      {'name': 'BROWN RICE *', 'price': 5100.0, 'gst': 0.0},
      {'name': 'OLD BPT RAW RICE', 'price': 4800.0, 'gst': 0.0},
      {'name': 'RGL', 'price': 3850.0, 'gst': 0.0},
      {'name': 'KARTHIKA BLUE', 'price': 3600.0, 'gst': 0.0},
      {'name': 'KARTHIKA BROWN', 'price': 3000.0, 'gst': 0.0},
      {'name': 'THICK GRADER TEJA', 'price': 3700.0, 'gst': 0.0},

      // GST 5%
      {'name': 'HMT GREEN GALAXY CLOTH (10kg)', 'price': 5400.0, 'gst': 5.0},
      {'name': 'HMT GREEN GALAXY CLOTH (5kg)', 'price': 5450.0, 'gst': 5.0},
      {'name': 'JEERA COPPER (10kg)', 'price': 5000.0, 'gst': 5.0},
      {'name': 'JEERA COPPER (5kg)', 'price': 5050.0, 'gst': 5.0},
      {'name': 'BPT BLUE GALAXY (10kg)', 'price': 4500.0, 'gst': 5.0},
      {'name': 'BPT BLUE GALAXY (5kg)', 'price': 4550.0, 'gst': 5.0},
      {'name': 'BPT RED GALAXY (10kg)', 'price': 4400.0, 'gst': 5.0},
      {'name': 'BPT RED GALAXY (5kg)', 'price': 4450.0, 'gst': 5.0},
      {'name': 'BROWN RICE (10kg)', 'price': 5100.0, 'gst': 5.0},
      {'name': 'BROWN RICE (5kg)', 'price': 5100.0, 'gst': 5.0},
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
