import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../theme.dart';
import '../main.dart';
import '../db/database.dart';
import '../widgets/safe_widgets.dart';
import 'customers_screen.dart';
import 'rice_varieties_screen.dart';
import 'new_order_screen.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';
import 'product_gallery_screen.dart';
import '../services/translation_service.dart';
import '../providers/settings_provider.dart';

/// Main Home Screen - Daily Order Dashboard for Rice Agent
/// FOCUS: Order Creation + Excel Export Only
/// USES: SafePage pattern for NO overflow errors
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
    if (mounted) Navigator.pop(context); // Close drawer safely
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _selectedIndex == 0
          ? null // No AppBar for Dashboard (Custom Header)
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(_getTitle(), overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => setState(() => _selectedIndex = 5),
                ),
              ],
            ),
      drawer: _buildNavigationDrawer(),
      body: _getCurrentScreen(),
    );
  }

  String _getTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'dashboard'.tr(ref);
      case 1:
        return 'new_order'.tr(ref);
      case 2:
        return 'customers'.tr(ref);
      case 3:
        return 'rice_varieties'.tr(ref);
      case 4:
        return 'orders'.tr(ref);
      case 5:
        return 'settings'.tr(ref);
      default:
        return 'dashboard'.tr(ref);
    }
  }

  Widget _buildNavigationDrawer() {
    // ... (existing drawer code) ...
    // Just omitting here for brevity in replacement, but ensure it matches original lines if not changing
    // actually, replace_file_content needs exact match.
    // Since I am modifying the build method to remove AppBar for dashboard, I need to be careful.
    // Let's just modify the build method and the DailyDashboard.

    // Actually, user wants "in main page rice agent asnd somthing remove it say good moring".
    // So distinct header is better.

    final theme = Theme.of(context);
    return NavigationDrawer(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onMenuTap,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: theme.primaryColor, width: 2),
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/sri_balaji_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'mill_name'.tr(ref),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // mill_description removed as per user request
            ],
          ),
        ),
        const SizedBox(height: 8),
        NavigationDrawerDestination(
          icon: const Icon(Icons.dashboard_outlined),
          label: Text('dashboard'.tr(ref)),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.add_shopping_cart_outlined),
          label: Text('new_order'.tr(ref)),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.people_outline),
          label: Text('customers'.tr(ref)),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.grass_outlined),
          label: Text('rice_varieties'.tr(ref)),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.history_outlined),
          label: Text('orders'.tr(ref)),
        ),
        const Divider(indent: 20, endIndent: 20, height: 24),
        NavigationDrawerDestination(
          icon: const Icon(Icons.settings_outlined),
          label: Text('settings'.tr(ref)),
        ),
      ],
    );
  }
}

class DailyDashboard extends ConsumerWidget {
  const DailyDashboard({super.key});

  (String, IconData) _getGreetingData() {
    final hour = DateTime.now().hour;
    if (hour < 12) return ('Good Morning', Icons.wb_sunny_outlined);
    if (hour < 17) return ('Good Afternoon', Icons.wb_cloudy_outlined);
    return ('Good Evening', Icons.nightlight_round_outlined);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return SafePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // CUSTOM HEADER with Gradient & Dynamic Greeting
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor,
                  theme.primaryColor.withValues(alpha: 0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getGreetingData().$2,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_getGreetingData().$1},',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Narendra',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          "ఒక్కసారి రుచిచూస్తే జీవితకాలం వదల్లేరు",
                          style: GoogleFonts.notoSerifTelugu(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // TODAY'S ORDER STATS
          _buildTodayStats(context, ref, db, startOfDay),
          const SizedBox(height: 24),

          // QUICK ACTIONS
          Text(
            'quick_actions'.tr(ref),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          _buildQuickActions(context, ref),

          const SizedBox(height: 24),

          // RECENT ORDERS
          Text(
            'recent_orders'.tr(ref),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          _buildRecentOrders(context, ref, db),
        ],
      ),
    );
  }

  // ... _buildTodayStats ...
  Widget _buildTodayStats(BuildContext context, WidgetRef ref, AppDatabase db,
      DateTime startOfDay) {
    return StreamBuilder<List<Order>>(
      stream: (db.select(db.orders)
            ..where((tbl) => tbl.loadingDate.isBiggerOrEqualValue(startOfDay)))
          .watch(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final todayOrders = snapshot.data!;
        final ordersCount = todayOrders.length;

        // Compute total QTL reactively from items associated with today's orders
        return StreamBuilder<List<OrderItem>>(
          stream: (db.select(db.orderItems)
                ..where((tbl) =>
                    tbl.orderId.isIn(todayOrders.map((o) => o.id).toList())))
              .watch(),
          builder: (context, itemsSnapshot) {
            final items = itemsSnapshot.data ?? [];
            final totalQtl = items.fold(0.0, (sum, item) => sum + item.qtyQtl);

            return Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context: context,
                    icon: Icons.local_shipping_outlined,
                    label: 'orders_today'.tr(ref),
                    value: ordersCount.toString(),
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context: context,
                    icon: Icons.scale_outlined,
                    label: 'total_qtl'.tr(ref),
                    value: totalQtl.toStringAsFixed(1),
                    color: Colors.orange,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Icon(icon, size: 48, color: color.withValues(alpha: 0.1)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.headlineSmall?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppTheme.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // First 4 items in Grid
    final gridActions = [
      (
        Icons.add_circle_outline,
        'new_order'.tr(ref),
        theme.primaryColor,
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const NewOrderScreen()))
      ),
      (
        Icons.history,
        'orders'.tr(ref),
        Colors.orange,
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const OrdersScreen()))
      ),
      (
        Icons.people_outline,
        'customers'.tr(ref),
        Colors.purple,
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const CustomersScreen()))
      ),
      (
        Icons.collections_outlined,
        'our_products'.tr(ref),
        Colors.teal,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProductGalleryScreen()))
      ),
    ];

    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3, // Taller tiles to prevent overflow
          children: gridActions.map((a) {
            return _buildActionButton(
              context: context,
              icon: a.$1,
              label: a.$2,
              color: a.$3,
              onTap: a.$4 as VoidCallback,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Settings as Full Width (Row Span 2 equivalent)
        _buildActionButton(
          context: context,
          icon: Icons.settings_outlined,
          label: 'settings'.tr(ref),
          color: Colors.blueGrey,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
          isFullWidth: true,
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
    bool isFullWidth = false,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: isFullWidth
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ])
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 28, color: color),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRecentOrders(
      BuildContext context, WidgetRef ref, AppDatabase db) {
    final theme = Theme.of(context);
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
          return SafeCard(
            color: theme.cardColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox_outlined,
                    size: 40, color: AppTheme.grey),
                const SizedBox(height: 12),
                Text(
                  'no_orders'.tr(ref),
                  style: const TextStyle(fontSize: 15, color: AppTheme.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'no_orders_helper'.tr(ref),
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: recentOrders.map((order) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.lightGrey),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.local_shipping,
                      color: theme.primaryColor, size: 20),
                ),
                title: Text(
                  order.notes ?? 'Order',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(order.loadingDate),
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (order.notes != null)
                      Text(
                        order.notes!,
                        style:
                            const TextStyle(fontSize: 12, color: AppTheme.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                trailing: SafeText(
                    '${ref.watch(settingsProvider).currencySymbol}${order.totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrdersScreen()),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
