import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../theme.dart';
import '../main.dart';
import '../db/database.dart';
import 'customers_screen.dart';
import 'rice_varieties_screen.dart';
import 'new_order_screen.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';
import 'product_gallery_screen.dart';

/// Main Home Screen - Daily Dashboard for Rice Agent
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
        return const ProductGalleryScreen();
      case 6:
        return const SettingsScreen();
      default:
        return const DailyDashboard();
    }
  }

  void _onMenuTap(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context); // Close drawer
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
                  Text('Daily Order & Payment Tracker',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.language),
                  onPressed: () {
                    // TODO: Language toggle
                  },
                ),
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
        return 'Product Gallery';
      case 6:
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
        Container(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
          decoration: const BoxDecoration(
            color: AppTheme.paleGreen,
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(32),
            ),
          ),
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
                'Narayana Murthy',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.charcoal,
                      fontWeight: FontWeight.w500,
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
        const NavigationDrawerDestination(
          icon: Icon(Icons.photo_library_outlined),
          label: Text('Product Gallery'),
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

/// Daily Dashboard Widget
class DailyDashboard extends ConsumerWidget {
  const DailyDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh data
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SECTION 1: TODAY'S STATUS
          const Text(
            "Today's Status",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 16),
          _buildTodayStats(db, startOfDay),

          const SizedBox(height: 32),

          // SECTION 2: QUICK ACTIONS
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

          // SECTION 3: PAYMENT ALERTS
          const Text(
            'Payment Follow-ups',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentAlerts(db),

          const SizedBox(height: 32),

          // SECTION 4: RECENT ACTIVITY
          const Text(
            'Recent Orders',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 16),
          _buildRecentOrders(db),
        ],
      ),
    );
  }

  Widget _buildTodayStats(AppDatabase db, DateTime startOfDay) {
    return StreamBuilder<List<Order>>(
      stream: (db.select(db.orders)
            ..where((tbl) => tbl.loadingDate.isBiggerOrEqualValue(startOfDay)))
          .watch(),
      builder: (context, snapshot) {
        final todayOrders = snapshot.data ?? [];
        final ordersCount = todayOrders.length;
        final totalValue =
            todayOrders.fold<double>(0, (sum, o) => sum + o.totalAmount);
        final amountReceived =
            todayOrders.fold<double>(0, (sum, o) => sum + o.amountPaid);
        final amountPending = totalValue - amountReceived;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _buildStatCard(
              icon: Icons.local_shipping_outlined,
              label: 'Orders Today',
              value: ordersCount.toString(),
              color: Colors.blue,
            ),
            _buildStatCard(
              icon: Icons.currency_rupee,
              label: 'Total Value',
              value: '₹${_formatAmount(totalValue)}',
              color: AppTheme.primaryGreen,
            ),
            _buildStatCard(
              icon: Icons.check_circle_outline,
              label: 'Received',
              value: '₹${_formatAmount(amountReceived)}',
              color: Colors.green,
            ),
            _buildStatCard(
              icon: Icons.pending_outlined,
              label: 'Pending',
              value: '₹${_formatAmount(amountPending)}',
              color: amountPending > 0 ? Colors.orange : Colors.grey,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.grey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
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
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context: context,
                icon: Icons.payment_outlined,
                label: 'Add Payment',
                color: Colors.blue,
                onTap: () {
                  // TODO: Navigate to payment screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Payment feature coming soon')),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context: context,
                icon: Icons.receipt_long_outlined,
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
            const SizedBox(width: 12),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
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

  Widget _buildPaymentAlerts(AppDatabase db) {
    return StreamBuilder<List<Order>>(
      stream: (db.select(db.orders)
            ..where((tbl) =>
                tbl.paymentStatus.equals('UNPAID') |
                tbl.paymentStatus.equals('PARTIAL'))
            ..orderBy([(tbl) => drift.OrderingTerm(expression: tbl.dueDate)]))
          .watch(),
      builder: (context, snapshot) {
        final pendingOrders = snapshot.data ?? [];

        if (pendingOrders.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'All payments are clear today.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: pendingOrders.take(5).map((order) {
            return FutureBuilder<List<Customer>>(
              future: (db.select(db.lorryShipments).join([
                drift.innerJoin(db.customers,
                    db.customers.id.equalsExp(db.lorryShipments.customerId)),
              ])
                    ..where(db.lorryShipments.orderId.equals(order.id)))
                  .get()
                  .then((rows) =>
                      rows.map((r) => r.readTable(db.customers)).toList()),
              builder: (context, customerSnapshot) {
                final customers = customerSnapshot.data ?? [];
                final customerName =
                    customers.isNotEmpty ? customers.first.shopName : 'Unknown';

                return _buildPaymentAlertCard(
                  customerName: customerName,
                  amount: order.totalAmount - order.amountPaid,
                  dueDate: order.dueDate,
                  status: order.paymentStatus,
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPaymentAlertCard({
    required String customerName,
    required double amount,
    required DateTime? dueDate,
    required String status,
  }) {
    final now = DateTime.now();
    final isOverdue = dueDate != null && dueDate.isBefore(now);
    final isDueToday = dueDate != null &&
        dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;

    Color statusColor = Colors.orange;
    String statusText = 'UPCOMING';

    if (isOverdue) {
      statusColor = Colors.red;
      statusText = 'OVERDUE';
    } else if (isDueToday) {
      statusColor = Colors.orange;
      statusText = 'DUE TODAY';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_formatAmount(amount)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                if (dueDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Due: ${DateFormat('dd MMM yyyy').format(dueDate)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders(AppDatabase db) {
    return StreamBuilder<List<Order>>(
      stream: (db.select(db.orders)
            ..orderBy([
              (tbl) => drift.OrderingTerm(
                  expression: tbl.createdAt, mode: drift.OrderingMode.desc)
            ])
            ..limit(3))
          .watch(),
      builder: (context, snapshot) {
        final recentOrders = snapshot.data ?? [];

        if (recentOrders.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.lightGrey,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'No orders yet. Create your first order!',
                style: TextStyle(color: AppTheme.grey),
              ),
            ),
          );
        }

        return Column(
          children: recentOrders.map((order) {
            return FutureBuilder<int>(
              future: (db.select(db.lorryShipments)
                    ..where((tbl) => tbl.orderId.equals(order.id)))
                  .get()
                  .then((shipments) => shipments.length),
              builder: (context, customerCountSnapshot) {
                final customerCount = customerCountSnapshot.data ?? 0;

                return _buildRecentOrderCard(
                  orderNo: order.notes ?? 'N/A',
                  date: order.loadingDate,
                  customerCount: customerCount,
                  totalAmount: order.totalAmount,
                  paymentStatus: order.paymentStatus,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OrdersScreen()),
                    );
                  },
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRecentOrderCard({
    required String orderNo,
    required DateTime date,
    required int customerCount,
    required double totalAmount,
    required String paymentStatus,
    required VoidCallback onTap,
  }) {
    Color statusColor = AppTheme.primaryGreen;
    if (paymentStatus == 'UNPAID') statusColor = Colors.red;
    if (paymentStatus == 'PARTIAL') statusColor = Colors.orange;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.lightGrey),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.paleGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: AppTheme.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #$orderNo',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('dd MMM yyyy').format(date)} • $customerCount customers',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_formatAmount(totalAmount)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                paymentStatus,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
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
