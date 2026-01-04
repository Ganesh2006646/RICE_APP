import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../theme.dart';
import '../main.dart';
import '../db/database.dart';
import 'customers_screen.dart';
import 'rice_varieties_screen.dart';
import 'new_order_screen.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';

/// Main Home Screen - Daily Order Dashboard for Rice Agent
/// FOCUS: Order Creation + Excel Export Only
/// NO: Payment tracking, due dates, accounting
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _getCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return const DailyDashboard();
      case 1:
        return const NewOrderScreen();
      case 2:
        return const CustomersScreen();
      case 3:
        return const RiceVarietiesScreen();
      case 4:
        return const OrdersScreen();
      case 5:
        return const SettingsScreen();
      default:
        return const DailyDashboard();
    }
  }

  void _onMenuTap(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _selectedIndex == 0
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RiceAgent',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Lorry Order & Excel Export',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => setState(() => _selectedIndex = 5),
                ),
              ],
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(_getTitle()),
            ),
      drawer: _buildNavigationDrawer(),
      body: SafeArea(child: _getCurrentScreen()),
    );
  }

  String _getTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'New Order';
      case 2:
        return 'Customers';
      case 3:
        return 'Rice Varieties';
      case 4:
        return 'Orders';
      case 5:
        return 'Settings';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildNavigationDrawer() {
    return NavigationDrawer(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onMenuTap,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: AppTheme.primaryGreen, width: 2),
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/sri_balaji_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sri Balaji Mill',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                'Order & Excel Tool',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.charcoal,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const NavigationDrawerDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: Text('Dashboard'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.add_shopping_cart_outlined),
          label: Text('New Order'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.people_outline),
          label: Text('Customers'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.grass_outlined),
          label: Text('Rice Varieties'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.history_outlined),
          label: Text('Orders'),
        ),
        const Divider(indent: 20, endIndent: 20, height: 24),
        const NavigationDrawerDestination(
          icon: Icon(Icons.settings_outlined),
          label: Text('Settings'),
        ),
      ],
    );
  }
}

/// Daily Dashboard - Simple Order Stats + Quick Actions
/// NO PAYMENT INFO - ORDER TOOL ONLY
class DailyDashboard extends ConsumerWidget {
  const DailyDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // TODAY'S ORDER STATS
          _buildTodayStats(context, db, startOfDay),

          const SizedBox(height: 32),

          // QUICK ACTIONS
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActions(context),

          const SizedBox(height: 32),

          // RECENT ORDERS
          const Text(
            'Recent Orders',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 16),
          _buildRecentOrders(context, db),
        ],
      ),
    );
  }

  Widget _buildTodayStats(
      BuildContext context, AppDatabase db, DateTime startOfDay) {
    return StreamBuilder<List<Order>>(
      stream: (db.select(db.orders)
            ..where((tbl) => tbl.loadingDate.isBiggerOrEqualValue(startOfDay)))
          .watch(),
      builder: (context, snapshot) {
        final todayOrders = snapshot.data ?? [];
        final ordersCount = todayOrders.length;

        // Calculate total QTL from lorry shipments
        return FutureBuilder<double>(
          future: _getTodayTotalQtl(db, startOfDay),
          builder: (context, qtlSnapshot) {
            final totalQtl = qtlSnapshot.data ?? 0.0;

            return Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.local_shipping_outlined,
                    label: 'Orders Today',
                    value: ordersCount.toString(),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.scale_outlined,
                    label: 'Total QTL',
                    value: totalQtl.toStringAsFixed(2),
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<double> _getTodayTotalQtl(AppDatabase db, DateTime startOfDay) async {
    try {
      final orders = await (db.select(db.orders)
            ..where((tbl) => tbl.loadingDate.isBiggerOrEqualValue(startOfDay)))
          .get();

      double totalQtl = 0.0;
      for (final order in orders) {
        final items = await (db.select(db.orderItems)
              ..where((tbl) => tbl.orderId.equals(order.id)))
            .get();
        for (final item in items) {
          totalQtl += item.qtyQtl;
        }
      }
      return totalQtl;
    } catch (e) {
      return 0.0;
    }
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context: context,
                icon: Icons.add_circle_outline,
                label: 'New Lorry Order',
                color: AppTheme.primaryGreen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NewOrderScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                context: context,
                icon: Icons.history,
                label: 'Orders',
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OrdersScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context: context,
                icon: Icons.people_outline,
                label: 'Customers',
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomersScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                context: context,
                icon: Icons.settings_outlined,
                label: 'Settings',
                color: Colors.blueGrey,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders(BuildContext context, AppDatabase db) {
    return StreamBuilder<List<Order>>(
      stream: (db.select(db.orders)
            ..orderBy([
              (tbl) => OrderingTerm(
                    expression: tbl.createdAt,
                    mode: OrderingMode.desc,
                  )
            ])
            ..limit(5))
          .watch(),
      builder: (context, snapshot) {
        final recentOrders = snapshot.data ?? [];

        if (recentOrders.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.lightGrey,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: AppTheme.grey),
                SizedBox(height: 16),
                Text(
                  'No orders yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap "New Lorry Order" to create your first order',
                  style: TextStyle(fontSize: 13, color: AppTheme.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: recentOrders.map((order) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.lightGrey),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.paleGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping,
                      color: AppTheme.primaryGreen),
                ),
                title: Text(
                  order.notes ?? 'Order',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  DateFormat('dd MMM yyyy').format(order.loadingDate),
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${_formatAmount(order.totalAmount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OrdersScreen()),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
