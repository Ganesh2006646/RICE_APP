import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../main.dart';
import '../db/database.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: StreamBuilder<List<OrderWithCustomer>>(
        stream: (db.select(db.orders)
              ..orderBy([
                (t) => drift.OrderingTerm(
                    expression: t.loadingDate, mode: drift.OrderingMode.desc)
              ]))
            .join([
              drift.innerJoin(
                  db.customers, db.customers.id.equalsExp(db.orders.customerId))
            ])
            .map((row) => OrderWithCustomer(
                  row.readTable(db.orders),
                  row.readTable(db.customers),
                ))
            .watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final orders = snapshot.data!;
          if (orders.isEmpty) return const Center(child: Text('No orders yet'));

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final item = orders[index];
              return ListTile(
                title: Text(item.customer.shopName),
                subtitle: Text(
                    DateFormat('dd-MM-yyyy').format(item.order.loadingDate)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${item.order.totalAmount.toStringAsFixed(2)}'),
                    if (item.order.isSynced)
                      const Icon(Icons.cloud_done,
                          size: 12, color: Colors.blue),
                  ],
                ),
                onTap: () {
                  // Show details
                },
              );
            },
          );
        },
      ),
    );
  }
}

class OrderWithCustomer {
  final Order order;
  final Customer customer;
  OrderWithCustomer(this.order, this.customer);
}
