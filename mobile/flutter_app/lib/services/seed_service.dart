import 'package:drift/drift.dart';
import '../db/database.dart';
import 'package:uuid/uuid.dart';

/// Service to populate initial data for testing and demonstration
class SeedService {
  static const _uuid = Uuid();

  /// Seeds the database with sample products and customers if they don't exist
  static Future<void> seedDatabase(AppDatabase db) async {
    // 1. Seed Products if empty
    final existingProducts = await db.select(db.products).get();
    if (existingProducts.isEmpty) {
      final products = [
        _p('BPT Premium Raw Rice', 5400.0, 0.0),
        _p('BPT Steam Rice', 5200.0, 0.0),
        _p('Swarna Boiled Rice', 4200.0, 0.0),
        _p('HMT Sona Masuri', 5800.0, 0.0),
        _p('NLR Raw Rice', 4800.0, 0.0),
        _p('Broken Rice (Kanki)', 2800.0, 0.0),
      ];

      for (var p in products) {
        await db.into(db.products).insert(p);
      }
    }

    // 2. Seed Customers if empty
    final existingCustomers = await db.select(db.customers).get();
    if (existingCustomers.isEmpty) {
      final customers = [
        _c('Sri Rama Traders', 'Guntur', '9848012345', '37AAAAA0000A1Z5'),
        _c('Laxmi General Stores', 'Vijayawada', '9866054321',
            '37BBBBB1111B1Z2'),
        _c('Venkateswara Rice Depot', 'Tenali', '9440123456', ''),
        _c('Durga Bhavani Merchants', 'Nellore', '9000190001',
            '37CCCCC2222C1Z3'),
        _c('Sai Baba Agencies', 'Ongole', '8885566778', ''),
      ];

      for (var c in customers) {
        await db.into(db.customers).insert(c);
      }
    }
  }

  static ProductsCompanion _p(String name, double price, double gst) {
    return ProductsCompanion.insert(
      id: _uuid.v4(),
      name: name,
      defaultPrice: price,
      gstRateDefault: Value(gst),
      createdAt: Value(DateTime.now()),
      updatedAt: DateTime.now(),
    );
  }

  static CustomersCompanion _c(
      String name, String place, String phone, String gst) {
    return CustomersCompanion.insert(
      id: _uuid.v4(),
      shopName: name,
      place: Value(place),
      phone: Value(phone),
      tinGst: Value(gst),
      createdAt: Value(DateTime.now()),
      updatedAt: DateTime.now(),
    );
  }
}
