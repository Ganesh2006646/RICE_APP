import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../main.dart'; // To access databaseProvider
import '../models/daily_order_stat.dart';
import '../models/rice_distribution.dart';
import '../repositories/analytics_repository.dart';

/// Provider for the AnalyticsRepository
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AnalyticsRepository(db);
});

/// Time filters for analytics
enum AnalyticsTimeFilter {
  last7Days('Last 7 Days'),
  last30Days('Last 30 Days'),
  thisMonth('This Month'),
  thisYear('This Year');

  final String label;
  const AnalyticsTimeFilter(this.label);
}

/// Display modes for analytics charts
enum AnalyticsMode {
  orders('Orders'),
  revenue('Revenue'),
  quantity('Quantity');

  final String label;
  const AnalyticsMode(this.label);
}

/// State provider for the active time filter
final analyticsTimeFilterProvider =
    StateProvider<AnalyticsTimeFilter>((ref) => AnalyticsTimeFilter.last30Days);

/// State provider for the active display mode
final analyticsModeProvider =
    StateProvider<AnalyticsMode>((ref) => AnalyticsMode.revenue);

/// Computes the start date based on the selected time filter
DateTime _getStartDateForFilter(AnalyticsTimeFilter filter) {
  final now = DateTime.now();
  switch (filter) {
    case AnalyticsTimeFilter.last7Days:
      return now.subtract(const Duration(days: 7));
    case AnalyticsTimeFilter.last30Days:
      return now.subtract(const Duration(days: 30));
    case AnalyticsTimeFilter.thisMonth:
      return DateTime(now.year, now.month, 1);
    case AnalyticsTimeFilter.thisYear:
      return DateTime(now.year, 1, 1);
  }
}

// ---------------------------------------------------------
// Internal StreamProviders for raw reactive data
// ---------------------------------------------------------
final _ordersStreamProvider = StreamProvider((ref) => ref.watch(analyticsRepositoryProvider).watchAllOrders());
final _orderItemsStreamProvider = StreamProvider((ref) => ref.watch(analyticsRepositoryProvider).watchAllOrderItems());
final _productsStreamProvider = StreamProvider((ref) => ref.watch(analyticsRepositoryProvider).watchAllProducts());

// ---------------------------------------------------------
// Daily Orders Provider (Filtered & Aggregated)
// ---------------------------------------------------------
final dailyOrdersProvider = Provider<AsyncValue<List<DailyOrderStat>>>((ref) {
  final filter = ref.watch(analyticsTimeFilterProvider);
  final startDate = _getStartDateForFilter(filter);
  
  final ordersAsync = ref.watch(_ordersStreamProvider);
  final itemsAsync = ref.watch(_orderItemsStreamProvider);
  
  if (ordersAsync.isLoading || itemsAsync.isLoading) return const AsyncValue.loading();
  if (ordersAsync.hasError) return AsyncValue.error(ordersAsync.error!, ordersAsync.stackTrace!);
  if (itemsAsync.hasError) return AsyncValue.error(itemsAsync.error!, itemsAsync.stackTrace!);

  final orders = ordersAsync.value!;
  final items = itemsAsync.value!;
  
  final filteredOrders = orders.where((o) => !o.loadingDate.isBefore(startDate));
  final validOrderIds = filteredOrders.map((o) => o.id).toSet();
  
  // Pre-calculate quantity per order
  final orderQuantities = <String, double>{};
  for (final item in items) {
    if (validOrderIds.contains(item.orderId)) {
      orderQuantities[item.orderId] = (orderQuantities[item.orderId] ?? 0) + item.qtyQtl;
    }
  }
  
  final grouped = <String, DailyOrderStat>{};
  final formatter = DateFormat('yyyy-MM-dd');
  
  for (final order in filteredOrders) {
    final day = formatter.format(order.loadingDate);
    if (!grouped.containsKey(day)) {
      grouped[day] = DailyOrderStat(day: day, totalOrders: 0, revenue: 0.0, quantity: 0.0);
    }
    
    final current = grouped[day]!;
    final orderQty = orderQuantities[order.id] ?? 0.0;
    
    grouped[day] = DailyOrderStat(
      day: day,
      totalOrders: current.totalOrders + 1,
      revenue: current.revenue + order.totalAmount,
      quantity: current.quantity + orderQty,
    );
  }
  
  // Sort chronologically ascending
  final sortedList = grouped.values.toList()
    ..sort((a, b) => a.day.compareTo(b.day));
    
  return AsyncValue.data(sortedList);
});

// ---------------------------------------------------------
// Rice Distribution Provider (Filtered & Aggregated)
// ---------------------------------------------------------
final riceDistributionProvider = Provider<AsyncValue<List<RiceDistribution>>>((ref) {
  final filter = ref.watch(analyticsTimeFilterProvider);
  final startDate = _getStartDateForFilter(filter);
  
  final ordersAsync = ref.watch(_ordersStreamProvider);
  final itemsAsync = ref.watch(_orderItemsStreamProvider);
  final productsAsync = ref.watch(_productsStreamProvider);
  
  if (ordersAsync.isLoading || itemsAsync.isLoading || productsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  
  if (ordersAsync.hasError) return AsyncValue.error(ordersAsync.error!, ordersAsync.stackTrace!);
  if (itemsAsync.hasError) return AsyncValue.error(itemsAsync.error!, itemsAsync.stackTrace!);
  if (productsAsync.hasError) return AsyncValue.error(productsAsync.error!, productsAsync.stackTrace!);

  final orders = ordersAsync.value!;
  final items = itemsAsync.value!;
  final products = productsAsync.value!;
  
  // Build lookup maps
  final validOrderIds = orders
      .where((o) => !o.loadingDate.isBefore(startDate))
      .map((o) => o.id)
      .toSet();
      
  final productMap = {for (final p in products) p.id: p.name};
  
  // Aggregate
  final grouped = <String, RiceDistribution>{};
  
  for (final item in items) {
    if (!validOrderIds.contains(item.orderId)) continue;
    
    final varietyName = productMap[item.productId] ?? 'Unknown';
    if (!grouped.containsKey(varietyName)) {
      grouped[varietyName] = RiceDistribution(varietyName: varietyName, quantity: 0.0, revenue: 0.0);
    }
    
    final current = grouped[varietyName]!;
    grouped[varietyName] = RiceDistribution(
      varietyName: varietyName,
      quantity: current.quantity + item.qtyQtl,
      revenue: current.revenue + item.netAmount,
    );
  }
  
  // Sort by revenue descending by default
  final sortedList = grouped.values.toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));
    
  return AsyncValue.data(sortedList);
});
