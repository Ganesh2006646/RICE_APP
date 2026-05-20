import '../../../db/database.dart';
import '../models/daily_order_stat.dart';
import '../models/rice_distribution.dart';

class AnalyticsRepository {
  final AppDatabase db;

  AnalyticsRepository(this.db);

  /// Watches all-time daily order statistics via custom SQL
  Stream<List<DailyOrderStat>> watchOrdersByDay() {
    return db.watchOrdersByDay();
  }

  /// Watches all-time rice variety distribution via custom SQL
  Stream<List<RiceDistribution>> watchRiceDistribution() {
    return db.watchRiceDistribution();
  }

  /// Watches raw orders for flexible client-side date filtering
  Stream<List<Order>> watchAllOrders() {
    return db.select(db.orders).watch();
  }

  /// Watches raw order items for flexible client-side date filtering
  Stream<List<OrderItem>> watchAllOrderItems() {
    return db.select(db.orderItems).watch();
  }

  /// Watches raw products to join with order items
  Stream<List<Product>> watchAllProducts() {
    return db.select(db.products).watch();
  }
}
