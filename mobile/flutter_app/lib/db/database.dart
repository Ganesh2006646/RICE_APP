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
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get agentName => text().nullable()();
  DateTimeColumn get loadingDate => dateTime()();
  TextColumn get emailTo => text().nullable()();
  TextColumn get notes => text().nullable()();
  RealColumn get totalAmount => real()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class OrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get productId => text().references(Products, #id)();

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

@DriftDatabase(
    tables: [Customers, Products, CustomerPrices, Orders, OrderItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
