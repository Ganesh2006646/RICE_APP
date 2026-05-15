import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../main.dart';
import '../db/database.dart';
import '../providers/settings_provider.dart';
import '../widgets/safe_widgets.dart';
import '../widgets/metric_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/section_header.dart';
import 'customers_screen.dart';
import 'rice_varieties_screen.dart';
import 'new_order_screen.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';

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
        return const _Dashboard();
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
        return const _Dashboard();
    }
  }

  void _onMenuTap(int index) {
    setState(() => _selectedIndex = index);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _selectedIndex == 0
          ? null
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(_getTitle(), overflow: TextOverflow.ellipsis),
              actions: [
                if (_selectedIndex != 5)
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
      case 0: return 'Dashboard';
      case 1: return 'New Order';
      case 2: return 'Customers';
      case 3: return 'Rice Varieties';
      case 4: return 'Orders';
      case 5: return 'Settings';
      default: return 'Dashboard';
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/sri_balaji_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.agriculture,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ref.watch(settingsProvider).millName,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const NavigationDrawerDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.add_shopping_cart_outlined),
          selectedIcon: Icon(Icons.add_shopping_cart),
          label: Text('New Order'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('Customers'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.grass_outlined),
          selectedIcon: Icon(Icons.grass),
          label: Text('Rice Varieties'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: Text('Orders'),
        ),
        const Divider(indent: 20, endIndent: 20, height: 24),
        const NavigationDrawerDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final settings = ref.watch(settingsProvider);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final dateStr = DateFormat('EEEE, d MMM yyyy').format(now);

    return SafePage(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildHeader(context, greeting, dateStr, settings.agentName),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricsSection(context, ref, db, todayStart, tomorrowStart),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(title: 'Quick Actions'),
                _buildQuickActions(context, ref),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(title: 'Business Pulse'),
                _buildBusinessPulse(context, ref, db, todayStart),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String greeting, String dateStr, String agentName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.xl),
          bottomRight: Radius.circular(AppRadius.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        agentName,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.sync, size: 14, color: Color(0xFF86EFAC)),
                const SizedBox(width: 6),
                Text(
                  'Auto Backup',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF86EFAC),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection(BuildContext context, WidgetRef ref, AppDatabase db, DateTime todayStart, DateTime tomorrowStart) {
    return StreamBuilder<List<Order>>(
      stream: (db.select(db.orders)
            ..where((t) => t.loadingDate.isBiggerOrEqualValue(todayStart.subtract(const Duration(days: 1))))
          ).watch(),
      builder: (context, snapshot) {
        final allOrders = snapshot.data ?? [];
        final todayOrders = allOrders.where((o) =>
            !o.loadingDate.isBefore(todayStart) && o.loadingDate.isBefore(tomorrowStart)).toList();
        final tomorrowOrders = allOrders.where((o) =>
            !o.loadingDate.isBefore(tomorrowStart) && o.loadingDate.isBefore(tomorrowStart.add(const Duration(days: 1)))).toList();

        return FutureBuilder<List<Customer>>(
          future: db.select(db.customers).get(),
          builder: (context, custSnapshot) {
            final customerCount = custSnapshot.data?.length ?? 0;
            return FutureBuilder<List<Product>>(
              future: db.select(db.products).get(),
              builder: (context, prodSnapshot) {
                final varietyCount = prodSnapshot.data?.length ?? 0;
                final todayRevenue = todayOrders.fold<double>(0, (s, o) => s + o.totalAmount);

                return FutureBuilder<List<OrderItem>>(
                  future: todayOrders.isEmpty ? Future.value(<OrderItem>[]) : _loadTodayItems(db, todayOrders),
                  builder: (context, itemsSnapshot) {
                    final totalQtl = itemsSnapshot.data?.fold<double>(0, (s, i) => s + i.qtyQtl) ?? 0.0;
                    return Column(
                      children: [
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: MetricCard(
                                icon: Icons.local_shipping_outlined,
                                label: "Today's Orders",
                                value: '${todayOrders.length}',
                                color: AppColors.primary,
                                backgroundColor: AppColors.cardGreen,
                                subtitle: '${totalQtl.toStringAsFixed(1)} QTL',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: MetricCard(
                                icon: Icons.event_outlined,
                                label: "Tomorrow's Orders",
                                value: '${tomorrowOrders.length}',
                                color: AppColors.warning,
                                backgroundColor: AppColors.cardGold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: MetricCard(
                                icon: Icons.people_outline,
                                label: 'Total Customers',
                                value: '$customerCount',
                                color: const Color(0xFF7C3AED),
                                backgroundColor: AppColors.cardPurple,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: MetricCard(
                                icon: Icons.grass_outlined,
                                label: 'Rice Varieties',
                                value: '$varietyCount',
                                color: const Color(0xFF0891B2),
                                backgroundColor: AppColors.cardTeal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: MetricCard(
                                icon: Icons.scale_outlined,
                                label: 'Total QTL (Today)',
                                value: totalQtl.toStringAsFixed(1),
                                color: AppColors.info,
                                backgroundColor: AppColors.cardBlue,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: MetricCard(
                                icon: Icons.currency_rupee_outlined,
                                label: 'Revenue (Today)',
                                value: '${ref.read(settingsProvider).currencySymbol}${todayRevenue.toStringAsFixed(0)}',
                                color: AppColors.secondary,
                                backgroundColor: AppColors.cardOrange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<OrderItem>> _loadTodayItems(AppDatabase db, List<Order> todayOrders) async {
    final orderIds = todayOrders.map((o) => o.id).toList();
    return await (db.select(db.orderItems)
          ..where((t) => t.orderId.isIn(orderIds)))
        .get();
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 0.9,
      children: [
        QuickActionCard(
          icon: Icons.add_circle_outline,
          label: 'New Order',
          color: AppColors.primary,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewOrderScreen())),
        ),
        QuickActionCard(
          icon: Icons.people_outline,
          label: 'Customers',
          color: const Color(0xFF7C3AED),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen())),
        ),
        QuickActionCard(
          icon: Icons.grass_outlined,
          label: 'Rice Varieties',
          color: const Color(0xFF0891B2),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiceVarietiesScreen())),
        ),
        QuickActionCard(
          icon: Icons.history,
          label: 'Order History',
          color: AppColors.warning,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
        ),
        QuickActionCard(
          icon: Icons.file_upload_outlined,
          label: 'Import Excel',
          color: AppColors.secondary,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen())),
        ),
        QuickActionCard(
          icon: Icons.settings_outlined,
          label: 'Settings',
          color: AppColors.info,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ],
    );
  }

  Widget _buildBusinessPulse(BuildContext context, WidgetRef ref, AppDatabase db, DateTime todayStart) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pulseTile(
            icon: Icons.trending_up,
            iconColor: AppColors.primary,
            label: 'Most Ordered Variety',
            value: 'Syncing...',
          ),
          const Divider(height: 1, indent: 56),
          _pulseTile(
            icon: Icons.star,
            iconColor: AppColors.secondary,
            label: 'Top Customer',
            value: 'Syncing...',
          ),
          const Divider(height: 1, indent: 56),
          _pulseTile(
            icon: Icons.receipt_long,
            iconColor: AppColors.info,
            label: 'Recent Order',
            value: 'Syncing...',
          ),
          const Divider(height: 1, indent: 56),
          _pulseTile(
            icon: Icons.check_circle,
            iconColor: AppColors.success,
            label: 'Last Export',
            value: 'Ready',
          ),
        ],
      ),
    );
  }

  Widget _pulseTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
        ],
      ),
    );
  }
}
