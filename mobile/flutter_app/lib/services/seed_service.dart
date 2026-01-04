import 'package:drift/drift.dart';
import '../db/database.dart';
import 'package:uuid/uuid.dart';

/// Service to populate initial data with Sri Balaji Rice Mill products
/// Based on official product catalog from www.sbrm.co.in
class SeedService {
  static const _uuid = Uuid();

  /// Seeds the database with Sri Balaji Rice Mill products and sample customers
  static Future<void> seedDatabase(AppDatabase db) async {
    // 1. Seed Products - Official Sri Balaji Product Line
    final existingProducts = await db.select(db.products).get();
    if (existingProducts.isEmpty) {
      final products = [
        // Galaxy Brand - Premium Products
        _p('Galaxy Sona Rice', 5400.0, 0.0,
            'Medium grain raw rice sourced from local villages of Andhra Pradesh. Aged up to 6 months before packaging with rich and unique aroma.'),

        _p('Galaxy HMT Jeera Rice', 5800.0, 0.0,
            'A unique and new age rice category. HMT is a good alternative to sona rice with similar looks and taste.'),

        _p('Galaxy Brown Rice', 6200.0, 0.0,
            'Whole rice rich in magnesium, phosphorus, selenium, and vitamin B6. Only outer husks removed, keeping rich nutrients intact.'),

        // Raw Non-Basmati Rice
        _p('Raw Non Basmati Rice - Premium', 4800.0, 0.0,
            'High quality raw non-basmati rice from Andhra Pradesh villages.'),

        _p('Raw Non Basmati Rice - Standard', 4200.0, 0.0,
            'Standard quality raw non-basmati rice for daily consumption.'),

        // Parboiled Rice
        _p('Non Basmati Parboiled Rice', 4600.0, 0.0,
            'Parboiled non-basmati rice with enhanced nutritional value.'),

        // Broken Rice Varieties
        _p('Non Basmati Broken Rice', 2800.0, 0.0,
            'Quality broken rice suitable for various culinary uses.'),

        _p('Parboiled Broken Rice', 2600.0, 0.0,
            'Parboiled broken rice, economical and nutritious.'),

        _p('Raw Broken Rice (Kanki)', 2400.0, 0.0,
            'Raw broken rice, ideal for animal feed and industrial use.'),

        // Additional Varieties
        _p('Swarna Boiled Rice', 4200.0, 0.0,
            'Popular boiled rice variety from Andhra Pradesh.'),

        _p('BPT Premium Raw Rice', 5400.0, 0.0,
            'Premium BPT variety raw rice with excellent grain quality.'),

        _p('BPT Steam Rice', 5200.0, 0.0,
            'Steam processed BPT rice for better texture and aroma.'),
      ];

      for (var p in products) {
        await db.into(db.products).insert(p);
      }
    }

    // 2. Seed Customers - Sample customers from Andhra Pradesh region
    final existingCustomers = await db.select(db.customers).get();
    if (existingCustomers.isEmpty) {
      final customers = [
        _c('Sri Rama Traders', 'Guntur', '9848012345', '37AAAAA0000A1Z5',
            'Kankatala Rama Rao'),
        _c('Laxmi General Stores', 'Vijayawada', '9866054321',
            '37BBBBB1111B1Z2', 'Patel Lakshmi Narayana'),
        _c('Venkateswara Rice Depot', 'Tenali', '9440123456', '',
            'Kota Venkateswara Rao'),
        _c('Durga Bhavani Merchants', 'Nellore', '9000190001',
            '37CCCCC2222C1Z3', 'Reddy Durga Prasad'),
        _c('Sai Baba Agencies', 'Ongole', '8885566778', '', 'Naidu Sai Kumar'),
        _c('Balaji Wholesale', 'Kakinada', '9849123456', '37DDDDD3333D1Z4',
            'Kotha Balaji'),
        _c('Tirupati Rice Traders', 'Rajahmundry', '9866789012', '',
            'Chowdary Tirupati Rao'),
      ];

      for (var c in customers) {
        await db.into(db.customers).insert(c);
      }
    }
  }

  static ProductsCompanion _p(String name, double price, double gst,
      [String? description]) {
    return ProductsCompanion.insert(
      id: _uuid.v4(),
      name: name,
      defaultPrice: price,
      gstRateDefault: Value(gst),
      sku: Value(description), // Using SKU field to store description
      createdAt: Value(DateTime.now()),
      updatedAt: DateTime.now(),
    );
  }

  static CustomersCompanion _c(String shopName, String place, String phone,
      String gst, String ownerName) {
    return CustomersCompanion.insert(
      id: _uuid.v4(),
      shopName: shopName,
      ownerName: Value(ownerName),
      place: Value(place),
      phone: Value(phone),
      tinGst: Value(gst),
      createdAt: Value(DateTime.now()),
      updatedAt: DateTime.now(),
    );
  }
}
