content = open(r'd:\dad\RiceAgent_Ready\RiceAgent\lib\services\excel_service.dart', 'rb').read()

# 1. Add isNewInsert field to the class
old1 = (
    b'  _UpdateStatus status;\r\n'
    b'  String? errorMsg;\r\n\r\n'
    b'  _PriceUpdateResult({\r\n'
    b'    required this.excelName,\r\n'
    b'    this.dbName,\r\n'
    b'    this.dbProductId,\r\n'
    b'    this.oldPrice,\r\n'
    b'    this.newPrice,\r\n'
    b'    this.newGst,\r\n'
    b'    this.newUnit,\r\n'
    b'    this.newSku,\r\n'
    b'    required this.status,\r\n'
    b'  });'
)
new1 = (
    b'  _UpdateStatus status;\r\n'
    b'  String? errorMsg;\r\n'
    b'  final bool isNewInsert;\r\n\r\n'
    b'  _PriceUpdateResult({\r\n'
    b'    required this.excelName,\r\n'
    b'    this.dbName,\r\n'
    b'    this.dbProductId,\r\n'
    b'    this.oldPrice,\r\n'
    b'    this.newPrice,\r\n'
    b'    this.newGst,\r\n'
    b'    this.newUnit,\r\n'
    b'    this.newSku,\r\n'
    b'    required this.status,\r\n'
    b'    this.isNewInsert = false,\r\n'
    b'  });'
)

# 2. Update commit block to handle both insert and update
old2 = (
    b'            await (db.update(db.products)\r\n'
    b'                  ..where((tbl) => tbl.id.equals(dbId)))\r\n'
    b'                .write(ProductsCompanion(\r\n'
    b'              sku: drift.Value(r.newSku),\r\n'
    b'              defaultPrice: drift.Value(r.newPrice!),\r\n'
    b'              gstRateDefault: drift.Value(r.newGst ?? 0.0),\r\n'
    b"              unit: drift.Value(r.newUnit ?? 'qtl'),\r\n"
    b"              isGalaxy: drift.Value(r.excelName.toUpperCase().contains('GALAXY')),\r\n"
    b'              updatedAt: drift.Value(now),\r\n'
    b'            ));\r\n'
    b'            r.markCommitted();'
)
new2 = (
    b'            if (r.isNewInsert) {\r\n'
    b'              await db.into(db.products).insert(ProductsCompanion(\r\n'
    b'                id: drift.Value(dbId),\r\n'
    b'                name: drift.Value(r.dbName ?? r.excelName),\r\n'
    b'                sku: drift.Value(r.newSku),\r\n'
    b'                defaultPrice: drift.Value(r.newPrice ?? 0.0),\r\n'
    b'                gstRateDefault: drift.Value(r.newGst ?? 0.0),\r\n'
    b"                unit: drift.Value(r.newUnit ?? 'qtl'),\r\n"
    b"                isGalaxy: drift.Value(r.excelName.toUpperCase().contains('GALAXY')),\r\n"
    b'                updatedAt: drift.Value(now),\r\n'
    b'              ));\r\n'
    b'            } else {\r\n'
    b'              await (db.update(db.products)\r\n'
    b'                    ..where((tbl) => tbl.id.equals(dbId)))\r\n'
    b'                  .write(ProductsCompanion(\r\n'
    b'                sku: drift.Value(r.newSku),\r\n'
    b'                defaultPrice: drift.Value(r.newPrice!),\r\n'
    b'                gstRateDefault: drift.Value(r.newGst ?? 0.0),\r\n'
    b"                unit: drift.Value(r.newUnit ?? 'qtl'),\r\n"
    b"                isGalaxy: drift.Value(r.excelName.toUpperCase().contains('GALAXY')),\r\n"
    b'                updatedAt: drift.Value(now),\r\n'
    b'              ));\r\n'
    b'            }\r\n'
    b'            r.markCommitted();'
)

c1 = old1 in content
c2 = old2 in content
print(f'class field block found: {c1}')
print(f'commit block found: {c2}')

if c1:
    content = content.replace(old1, new1, 1)
    print('Applied patch 1 (isNewInsert field)')
else:
    print('WARN: patch 1 not found')

if c2:
    content = content.replace(old2, new2, 1)
    print('Applied patch 2 (commit insert/update)')
else:
    print('WARN: patch 2 not found')

open(r'd:\dad\RiceAgent_Ready\RiceAgent\lib\services\excel_service.dart', 'wb').write(content)
print('File saved.')
