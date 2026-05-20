import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../main.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import '../widgets/analytics_tile.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/loading_skeleton.dart';
import 'analytics_screen.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_header.dart';
import 'customers_screen.dart';
import 'new_order_screen.dart';
import 'orders_screen.dart';
import 'rice_varieties_screen.dart';
import 'settings_screen.dart';
import 'product_gallery_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    _Dashboard(),
    OrdersScreen(),
    CustomersScreen(),
    RiceVarietiesScreen(),
    SettingsScreen(),
  ];

  void _openNewOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewOrderScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      floatingActionButton: _selectedIndex == 4
          ? null
          : FloatingActionButton.extended(
              heroTag: 'home_fab',
              onPressed: _openNewOrder,
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: const Text('New Order'),
            ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.borderLight)),
          boxShadow: AppShadows.soft,
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Customers',
            ),
            NavigationDestination(
              icon: Icon(Icons.grass_outlined),
              selectedIcon: Icon(Icons.grass),
              label: 'Varieties',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
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
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(settingsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          children: [
            _DashboardHeader(
              greeting: greeting,
              businessName: settings.millName,
              agentName: settings.agentName,
            ),
            const SizedBox(height: AppSpacing.xl),
            StreamBuilder<List<Order>>(
              stream: db.select(db.orders).watch(),
              builder: (context, snapshot) {
                final orders = snapshot.data;
                if (orders == null) return const _DashboardSkeleton();

                return FutureBuilder<_DashboardStats>(
                  future: _DashboardStats.load(db, orders),
                  builder: (context, statsSnapshot) {
                    if (!statsSnapshot.hasData) {
                      return const _DashboardSkeleton();
                    }
                    final stats = statsSnapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AnalyticsGrid(
                          stats: stats,
                          currencySymbol: settings.currencySymbol,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const SectionHeader(title: 'Business Pulse'),
                        const SizedBox(height: AppSpacing.md),
                        _BusinessPulse(stats: stats),
                        const SizedBox(height: AppSpacing.xl),
                        const SectionHeader(title: 'Advanced Analytics'),
                        const SizedBox(height: AppSpacing.md),
                        const _AnalyticsPortalCard(),
                        const SizedBox(height: AppSpacing.xl),
                        const SectionHeader(title: 'Gallery'),
                        const SizedBox(height: AppSpacing.md),
                        _GalleryButton(),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String greeting;
  final String businessName;
  final String agentName;

  const _DashboardHeader({
    required this.greeting,
    required this.businessName,
    required this.agentName,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      agentName,
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                              ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.asset(
                    'assets/images/sri_balaji_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.agriculture_outlined,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            businessName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _HeaderPill(icon: Icons.calendar_today_outlined, label: dateStr),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsGrid extends StatelessWidget {
  final _DashboardStats stats;
  final String currencySymbol;

  const _AnalyticsGrid({
    required this.stats,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: MetricCard(
            icon: Icons.people_outline,
            label: 'Customers',
            value: '${stats.customers}',
            color: AppColors.info,
            backgroundColor: AppColors.cardBlue,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: MetricCard(
            icon: Icons.grass_outlined,
            label: 'Varieties',
            value: '${stats.varieties}',
            color: const Color(0xFF6F5FA8),
            backgroundColor: AppColors.cardPurple,
          ),
        ),
      ],
    );
  }
}

class _GalleryButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, _) => const ProductGalleryScreen(),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(
              opacity:
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.9),
              AppColors.primaryDark,
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.photo_library_outlined,
                  size: 28, color: Colors.white),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Product Gallery',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Browse all rice varieties',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }
}



class _BusinessPulse extends StatelessWidget {
  final _DashboardStats stats;

  const _BusinessPulse({required this.stats});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnalyticsTile(
            icon: Icons.workspace_premium_outlined,
            label: 'Most Ordered Rice',
            value: stats.topVariety ?? 'No orders yet',
            subtitle:
                stats.topVariety == null ? 'Start with a new order' : null,
            color: AppColors.primary,
          ),
          const Divider(height: 24),
          AnalyticsTile(
            icon: Icons.storefront_outlined,
            label: 'Top Customer',
            value: stats.topCustomer ?? 'No customer activity',
            color: AppColors.secondary,
          ),
          const Divider(height: 24),
          AnalyticsTile(
            icon: Icons.receipt_long_outlined,
            label: 'Recent Order',
            value: stats.recentOrder ?? 'No recent order',
            color: AppColors.info,
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const crossAxisSpacing = AppSpacing.md;
            const mainAxisSpacing = AppSpacing.md;
            // 2 items per row
            final cellWidth = (constraints.maxWidth - crossAxisSpacing) / 2;
            return Wrap(
              spacing: crossAxisSpacing,
              runSpacing: mainAxisSpacing,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: cellWidth,
                  child: const DashboardCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LoadingSkeleton(width: 44, height: 44),
                        SizedBox(height: AppSpacing.lg),
                        LoadingSkeleton(width: 88, height: 24),
                        SizedBox(height: AppSpacing.sm),
                        LoadingSkeleton(width: 120, height: 14),
                      ],
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

class _DashboardStats {
  final int todayOrders;
  final int tomorrowOrders;
  final int customers;
  final int varieties;
  final double todayQtl;
  final double tomorrowQtl;
  final double revenue;
  final String? topCustomer;
  final String? topVariety;
  final String? recentOrder;
  final List<_ActivityItem> recentActivities;

  const _DashboardStats({
    required this.todayOrders,
    required this.tomorrowOrders,
    required this.customers,
    required this.varieties,
    required this.todayQtl,
    required this.tomorrowQtl,
    required this.revenue,
    required this.topCustomer,
    required this.topVariety,
    required this.recentOrder,
    required this.recentActivities,
  });

  static Future<_DashboardStats> load(
    AppDatabase db,
    List<Order> orders,
  ) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final dayAfterTomorrow = tomorrowStart.add(const Duration(days: 1));

    final todayOrders = orders
        .where((o) =>
            !o.loadingDate.isBefore(todayStart) &&
            o.loadingDate.isBefore(tomorrowStart))
        .toList();
    final tomorrowOrders = orders
        .where((o) =>
            !o.loadingDate.isBefore(tomorrowStart) &&
            o.loadingDate.isBefore(dayAfterTomorrow))
        .toList();

    final customers = await db.select(db.customers).get();
    final products = await db.select(db.products).get();
    final allItems = await db.select(db.orderItems).get();
    final productMap = {for (final product in products) product.id: product};
    final customerMap = {
      for (final customer in customers) customer.id: customer
    };

    final todayIds = todayOrders.map((o) => o.id).toSet();
    final tomorrowIds = tomorrowOrders.map((o) => o.id).toSet();

    final todayQtl = allItems
        .where((item) => todayIds.contains(item.orderId))
        .fold<double>(0, (sum, item) => sum + item.qtyQtl);
    final tomorrowQtl = allItems
        .where((item) => tomorrowIds.contains(item.orderId))
        .fold<double>(0, (sum, item) => sum + item.qtyQtl);
    final revenue =
        todayOrders.fold<double>(0, (sum, order) => sum + order.totalAmount);

    final varietyTotals = <String, double>{};
    final customerTotals = <String, double>{};
    for (final item in allItems) {
      final productName = productMap[item.productId]?.name;
      final customerName = customerMap[item.customerId]?.shopName;
      if (productName != null) {
        varietyTotals[productName] =
            (varietyTotals[productName] ?? 0) + item.qtyQtl;
      }
      if (customerName != null) {
        customerTotals[customerName] =
            (customerTotals[customerName] ?? 0) + item.netAmount;
      }
    }

    String? topVariety;
    if (varietyTotals.isNotEmpty) {
      topVariety = varietyTotals.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    String? topCustomer;
    if (customerTotals.isNotEmpty) {
      topCustomer = customerTotals.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    final sortedOrders = [...orders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentOrder = sortedOrders.isEmpty
        ? null
        : sortedOrders.first.notes ??
            DateFormat('dd MMM').format(sortedOrders.first.loadingDate);

    final activities = sortedOrders.take(4).map((order) {
      return _ActivityItem(
        title: order.notes ?? 'Lorry order',
        subtitle:
            'Loading ${DateFormat('dd MMM yyyy').format(order.loadingDate)}',
        status: order.totalAmount.toStringAsFixed(0),
      );
    }).toList();

    return _DashboardStats(
      todayOrders: todayOrders.length,
      tomorrowOrders: tomorrowOrders.length,
      customers: customers.length,
      varieties: products.length,
      todayQtl: todayQtl,
      tomorrowQtl: tomorrowQtl,
      revenue: revenue,
      topCustomer: topCustomer,
      topVariety: topVariety,
      recentOrder: recentOrder,
      recentActivities: activities,
    );
  }
}

class _ActivityItem {
  final String title;
  final String subtitle;
  final String status;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.status,
  });
}

class _AnalyticsPortalCard extends StatelessWidget {
  const _AnalyticsPortalCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
        );
      },
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Interactive Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View daily trends & rice variety demand',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
