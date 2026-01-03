import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import 'customers_screen.dart';
import 'rice_varieties_screen.dart';
import 'new_order_screen.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';

/// Main container screen with navigation drawer
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
        return _buildSimpleDashboard();
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
        return _buildSimpleDashboard();
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
      appBar: AppBar(
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
        return 'Sri Balaji Mill';
      case 1:
        return 'New Order';
      case 2:
        return 'Customers';
      case 3:
        return 'Rice Varieties';
      case 4:
        return 'Order History';
      case 5:
        return 'Settings';
      default:
        return 'Sri Balaji Mill';
    }
  }

  Widget _buildSimpleDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          children: [
            // Placeholder for Brand Logo
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.paleGreen,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha:0.2), width: 2),
              ),
              child: const Icon(
                Icons.business_outlined,
                size: 80,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 32),

            // Mill Name
            Text(
              'Sri Balaji Boiled and Raw Rice Mill',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 12),

            // Personalized Welcome
            Text(
              'Kankatala Narayana Murthy',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.charcoal,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.accentGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 48),

            // Actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _selectedIndex = 1),
                icon: const Icon(Icons.add_shopping_cart, size: 20),
                label: const Text('CREATE NEW ORDER'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select an option from the menu or start a new booking above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
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
              const CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.primaryGreen,
                child: Icon(Icons.business, color: Colors.white, size: 30),
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
        const Divider(indent: 20, endIndent: 20, height: 24),
        const NavigationDrawerDestination(
          icon: Icon(Icons.settings_outlined),
          label: Text('Settings'),
        ),
      ],
    );
  }
}
