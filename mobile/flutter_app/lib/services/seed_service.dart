import '../db/database.dart';

/// Service to populate initial data if needed
/// Data should be added via the app UI (Customers screen, Rice Varieties screen)
class SeedService {
  /// Seeds the database - currently empty as data is added via app UI
  /// Add customers via: Home → Customers → (+) Add Customer
  /// Add products via: Home → Rice Varieties → (+) Add Variety
  static Future<void> seedDatabase(AppDatabase db) async {
    // No sample data seeded - add data via the app UI
    // This method is kept for potential future use (e.g., default settings)
  }
}
