import 'package:flutter/material.dart';
import 'customers_screen.dart';
import 'products_screen.dart';
import 'new_order_wizard.dart';
import 'orders_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RiceAgent')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _HomeButton(
              icon: Icons.add_shopping_cart,
              label: 'New Order',
              color: Colors.green.shade100,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewOrderWizard())),
            ),
            _HomeButton(
              icon: Icons.people,
              label: 'Customers',
              color: Colors.blue.shade100,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen())),
            ),
            _HomeButton(
              icon: Icons.inventory,
              label: 'Products',
              color: Colors.orange.shade100,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen())),
            ),
            _HomeButton(
              icon: Icons.list_alt,
              label: 'Orders',
              color: Colors.purple.shade100,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
            ),
            _HomeButton(
              icon: Icons.dashboard,
              label: 'Dashboard',
              color: Colors.teal.shade100,
              onTap: () {}, // TODO
            ),
            _HomeButton(
              icon: Icons.settings,
              label: 'Settings',
              color: Colors.grey.shade300,
              onTap: () {}, // TODO
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HomeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.black87),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
