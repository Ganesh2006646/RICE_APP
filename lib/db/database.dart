import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get shopName => text()();
  TextColumn get ownerName => text().nullable()();
  TextColumn get place => text().nullable()();
  TextColumn get tinGst => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get sku => text().nullable().unique()();
  TextColumn get name => text()();
  RealColumn get defaultPrice => real()(); // Rate per QTL
  RealColumn get gstRateDefault => real().withDefault(const Constant(0.0))();
  TextColumn get unit => text().withDefault(const Constant('qtl'))();
  BoolColumn get isGalaxy => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CustomerPrices extends Table {
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get price => real()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {customerId, productId};
}

class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()
      .nullable()
      .references(Customers, #id)(); // Now nullable for Lorry loads
  TextColumn get agentName => text().nullable()();
  DateTimeColumn get loadingDate => dateTime()();
  TextColumn get emailTo => text().nullable()();
  TextColumn get notes => text().nullable()(); // Used for Order Number
  RealColumn get totalAmount => real()();
  RealColumn get lorryCapacity =>
      real().withDefault(const Constant(120.0))(); // Default capacity

  // Payment tracking fields
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('UNPAID'))(); // UNPAID, PARTIAL, PAID

  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(Orders, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get paymentDate =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get method => text().nullable()(); // Cash, Bank, UPI, etc.
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LorryShipments extends Table {
  TextColumn get id => text()(); // orderId_customerId
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get customerId => text().references(Customers, #id)();

  RealColumn get totalAmount => real()();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('UNPAID'))();

  @override
  Set<Column> get primaryKey => {id};
}

class OrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get customerId => text().references(Customers, #id)();

  IntColumn get bags26 => integer().withDefault(const Constant(0))();
  IntColumn get bags10 => integer().withDefault(const Constant(0))();
  IntColumn get bags5 => integer().withDefault(const Constant(0))();

  RealColumn get qtyKg => real()();
  RealColumn get qtyQtl => real()();
  RealColumn get ratePerQtl => real()();
  RealColumn get amcPercent => real().withDefault(const Constant(1.0))();
  RealColumn get gstPercent => real()();

  RealColumn get lineAmount => real()();
  RealColumn get amcAmount => real()();
  RealColumn get gstAmount => real()();
  RealColumn get netAmount => real()();
  TextColumn get remarks => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncMeta extends Table {
  TextColumn get localId => text()();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get lastSyncAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncState => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {localId};
}

@DriftDatabase(tables: [
  Customers,
  Products,
  CustomerPrices,
  Orders,
  Payments,
  OrderItems,
  LorryShipments,
  SyncMeta
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(orders, orders.amountPaid);
          await m.addColumn(orders, orders.dueDate);
          await m.addColumn(orders, orders.paymentStatus);
          await m.createTable(payments);
        }
        if (from < 3) {
          await m.addColumn(orders, orders.lorryCapacity);
          // await m.alterTable(TableMigration(orders));
          await m.addColumn(orderItems, orderItems.customerId);
          await m.createTable(lorryShipments);
        }
        if (from < 4) {
          // Robust index creation using raw SQL to ensure compatibility
          await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS customers_name_idx ON customers (shop_name)');
          await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS products_name_idx ON products (name)');
          await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS orders_date_idx ON orders (loading_date)');
        }
        if (from < 5) {
          await m.addColumn(products, products.isGalaxy);
        }
      },
    );
  }
}

class OrderWithDetails {
  final Order order;
  final List<Customer> customers;
  final List<OrderItem> items;
  final List<LorryShipment> shipments;

  OrderWithDetails(
      {required this.order,
      required this.customers,
      this.items = const [],
      this.shipments = const []});
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
