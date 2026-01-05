import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import 'package:drift/drift.dart' as drift;

/// Service for generating Excel files matching the strict rice mill order format.
/// Supports multi-customer lorry loads with grouping and exact visual alignment.
class ExcelService {
  /// Generate Excel file for a multi-customer lorry order
  /// Matches the strict provided mill format exactly.
  static Future<String> generateLorryExcel({
    required Order order,
    required List<OrderItem> items,
    required List<Customer> customers,
    required List<Product> products,
    required String orderNumber,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = 'ORDER_$orderNumber';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    // --- STYLES ---
    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );

    final centerStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );

    final leftStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // --- TOP HEADER ---
    // Row 1: OM SRI GURUBHYONAMAHA KANKATALA NARAYANA MURTHY ORDER FORM
    final cellA1 = sheet.cell(CellIndex.indexByString('A1'));
    cellA1.value = TextCellValue(
        'OM SRI GURUBHYONAMAHA  KANKATALA NARAYANA MURTHY ORDER FORM');
    cellA1.cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('M1'));

    // Row 2: ORDER NO - <ORDER_NO>
    final cellA2 = sheet.cell(CellIndex.indexByString('A2'));
    cellA2.value = TextCellValue('ORDER NO - $orderNumber');
    cellA2.cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('M2'));

    // Row 3: Loading Date (Aligned Right)
    final cellM3 = sheet.cell(CellIndex.indexByString('M3'));
    cellM3.value = TextCellValue(
        'LOADING DATE : ${DateFormat('dd-MM-yyyy').format(order.loadingDate)}');
    cellM3.cellStyle =
        CellStyle(fontSize: 10, horizontalAlign: HorizontalAlign.Right);

    // --- TABLE HEADERS (14 Columns mapped to indices 0-13) ---
    // Column Index Mapping:
    // 0: SL | 1: PARTY NAME | 2: PLACE | 3: TIN / GST | 4: CELL | 5: TYPE OF RICE
    // 6: 26 KG | 7: 10 KG | 8: 5 KG | 9: QTL | 10: RATE | 11: AMC | 12: GST | 13: EX INFO

    // Row 4: Main Header
    final mainHeaders = [
      'SL',
      'PARTY NAME',
      'PLACE',
      'TIN / GST',
      'CELL',
      'TYPE OF RICE',
      '26 KG',
      '10 KG',
      '5 KG',
      'TOTAL',
      'BASE RATE',
      'AMC',
      'GST',
      'EX INFO'
    ];

    for (int i = 0; i < mainHeaders.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      cell.value = TextCellValue(mainHeaders[i]);
      cell.cellStyle = headerStyle;
    }

    // Row 5: Sub Header
    final subHeaders = [
      '',
      '',
      '',
      '',
      '',
      '',
      'BAGS',
      'QTL',
      'QTL',
      'QTL',
      'PER 100 KG',
      '1%',
      'TAX',
      'TOTAL'
    ];
    for (int i = 0; i < subHeaders.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4));
      if (subHeaders[i].isNotEmpty) {
        cell.value = TextCellValue(subHeaders[i]);
      }
      cell.cellStyle = headerStyle;
    }

    // Set Column Widths
    final widths = [
      5.0,
      25.0,
      15.0,
      18.0,
      15.0,
      20.0,
      8.0,
      10.0,
      10.0,
      10.0,
      12.0,
      8.0,
      8.0,
      15.0
    ];
    for (int i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }

    // --- DATA ROWS ---
    int rowIndex = 5;
    int slNo = 1;

    // Group items by customer
    final groupedItems = <String, List<OrderItem>>{};
    for (var item in items) {
      groupedItems.putIfAbsent(item.customerId, () => []).add(item);
    }

    for (var customerId in groupedItems.keys) {
      final customer = customers.firstWhere((c) => c.id == customerId);
      final customerItems = groupedItems[customerId]!;

      for (int i = 0; i < customerItems.length; i++) {
        final item = customerItems[i];
        final product = products.firstWhere((p) => p.id == item.productId);

        final isFirstRow = i == 0;

        // Calculations (Strict Mill Logic)
        final qtl10 = (item.bags10 * 10) / 100.0;
        final qtl5 = (item.bags5 * 5) / 100.0;
        final totalQtl = item.qtyQtl;

        final rowData = [
          isFirstRow ? slNo.toString() : '-', // 0: SL
          isFirstRow ? (customer.shopName) : '-', // 1: PARTY NAME
          isFirstRow ? (customer.place ?? '-') : '-', // 2: PLACE
          isFirstRow ? (customer.tinGst ?? '-') : '-', // 3: TIN / GST
          isFirstRow ? (customer.phone ?? '-') : '-', // 4: CELL
          product.name, // 5: TYPE OF RICE
          item.bags26 > 0 ? item.bags26.toString() : '-', // 6: 26 KG BAGS
          qtl10 > 0 ? qtl10.toStringAsFixed(2) : '-', // 7: 10 KG QTL
          qtl5 > 0 ? qtl5.toStringAsFixed(2) : '-', // 8: 5 KG QTL
          totalQtl > 0 ? totalQtl.toStringAsFixed(2) : '-', // 9: TOTAL QTL
          item.ratePerQtl > 0
              ? item.ratePerQtl.toStringAsFixed(2)
              : '-', // 10: BASE RATE
          item.amcAmount > 0
              ? item.amcAmount.toStringAsFixed(2)
              : '-', // 11: AMC (1%)
          item.gstAmount > 0
              ? item.gstAmount.toStringAsFixed(2)
              : '-', // 12: GST
          item.netAmount
              .toStringAsFixed(2), // 13: EX INFO (Grand Total for line)
        ];
        for (int j = 0; j < rowData.length; j++) {
          final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex));
          cell.value = TextCellValue(rowData[j]);
          cell.cellStyle =
              (j == 1 || j == 2 || j == 5) ? leftStyle : centerStyle;
        }
        rowIndex++;
      }
      slNo++;
    }

    // --- SAVE ---
    final directory = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final fileName = 'order_${orderNumber}_$dateStr.xlsx';
    final filePath = '${directory.path}/$fileName';

    final fileBytes = excel.save();
    if (fileBytes != null) {
      await File(filePath).writeAsBytes(fileBytes);
    }

    return filePath;
  }

  /// Get the downloads directory path for the user
  static Future<String> getDownloadsPath({String? customPath}) async {
    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (await dir.exists()) return customPath;
    }

    if (Platform.isAndroid) {
      final directory = Directory('/storage/emulated/0/Download');
      if (await directory.exists()) {
        return directory.path;
      }
    }
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Copy file to downloads folder for easy access
  static Future<String> copyToDownloads(String sourcePath,
      {String? customPath}) async {
    try {
      final sourceFile = File(sourcePath);
      final downloadsPath = await getDownloadsPath(customPath: customPath);
      final fileName = sourcePath.split(Platform.pathSeparator).last;

      // Ensure directory exists
      final dir = Directory(downloadsPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final destPath = '$downloadsPath/$fileName';

      // Verify write permission by attempting to write a test file
      if (Platform.isAndroid) {
        // If custom path is set, we assume permission is handled by the picker
        // If default, we might need to be careful with Scoped Storage
      }

      await sourceFile.copy(destPath);
      return destPath;
    } catch (e) {
      // Fallback: Just return source path (app docs dir) if copy fails
      // This prevents the "Success" message from showing a path that doesn't exist
      print('Excel Copy Failed: $e');
      return sourcePath;
    }
  }

  /// Generate a summary Excel for ALL orders (Statement)
  static Future<String> generateAllOrdersExcel({
    required List<OrderWithDetails> orders,
    required List<Product> products,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Orders Summary'];
    excel.rename('Sheet1', 'Orders Summary');

    final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin));
    final moneyStyle = CellStyle(horizontalAlign: HorizontalAlign.Right);

    // Headers
    final headers = [
      'DATE',
      'ORDER #',
      'CUSTOMERS',
      'B10',
      'B26',
      'B5',
      'QTL',
      'TOTAL AMT'
    ];
    for (int i = 0; i < headers.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    double grandTotalQtl = 0;
    double grandTotalAmt = 0;

    for (int i = 0; i < orders.length; i++) {
      final item = orders[i];
      final row = i + 1;

      final custNames = item.customers.map((c) => c.shopName).join(', ');
      final date = DateFormat('dd-MM-yyyy').format(item.order.loadingDate);

      // Sum items
      double orderQtl = 0;
      int b10 = 0, b26 = 0, b5 = 0;
      for (var oi in item.items) {
        b10 += oi.bags10;
        b26 += oi.bags26;
        b5 += oi.bags5;
        orderQtl += oi.qtyQtl;
      }

      final data = [
        date,
        item.order.notes ?? item.order.id,
        custNames,
        b10.toString(),
        b26.toString(),
        b5.toString(),
        orderQtl.toStringAsFixed(2),
        item.order.totalAmount.toStringAsFixed(2)
      ];

      for (int j = 0; j < data.length; j++) {
        final cell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
        cell.value = TextCellValue(data[j]);
        if (j >= 6) cell.cellStyle = moneyStyle;
      }

      grandTotalQtl += orderQtl;
      grandTotalAmt += item.order.totalAmount;
    }

    // Totals Row
    final totalRowIdx = orders.length + 1;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: totalRowIdx))
        .value = TextCellValue('GRAND TOTAL:');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: totalRowIdx))
        .value = TextCellValue(grandTotalQtl.toStringAsFixed(2));
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: totalRowIdx))
        .value = TextCellValue(grandTotalAmt.toStringAsFixed(2));

    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'All_Orders_Statement_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final filePath = '${directory.path}/$fileName';

    final bytes = excel.save();
    if (bytes != null) await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  /// Import Customers from an Excel file
  /// Expected Column Headers: Shop Name, Place, Phone, GST
  static Future<Map<String, dynamic>> importCustomersFromExcel(
      AppDatabase db) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) {
        return {'success': false, 'message': 'No file selected'};
      }

      File file = File(result.files.single.path!);
      var bytes = await file.readAsBytes();
      var excel = Excel.decodeBytes(bytes);

      int importedCount = 0;
      int skippedCount = 0;

      await db.transaction(() async {
        for (var table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet == null || sheet.maxRows == 0) continue;

          // Find headers in first row
          final headers = <String, int>{};
          final firstRow = sheet.rows.first;
          for (int i = 0; i < firstRow.length; i++) {
            final cellValue = firstRow[i]?.value.toString().toLowerCase() ?? '';
            if (cellValue.contains('name') || cellValue.contains('party')) {
              headers['name'] = i;
            } else if (cellValue.contains('place') ||
                cellValue.contains('city')) {
              headers['place'] = i;
            } else if (cellValue.contains('phone') ||
                cellValue.contains('mobile') ||
                cellValue.contains('cell')) {
              headers['phone'] = i;
            } else if (cellValue.contains('gst') || cellValue.contains('tin')) {
              headers['gst'] = i;
            }
          }

          // If no 'name' column found, assume rigid structure: 0=Name, 1=Place, 2=Phone, 3=GST
          if (!headers.containsKey('name')) {
            headers['name'] = 0;
            headers['place'] = 1;
            headers['phone'] = 2;
            headers['gst'] = 3;
          }

          // Iterate Rows (Skip header)
          for (int i = 1; i < sheet.rows.length; i++) {
            final row = sheet.rows[i];
            if (row.isEmpty) continue;

            String getValue(int? idx) {
              if (idx == null || idx >= row.length) return '';
              final val = row[idx]?.value;
              return val?.toString().trim() ?? '';
            }

            final name = getValue(headers['name']);
            if (name.isEmpty) continue; // Skip if no name

            final place = getValue(headers['place']);
            final phone = getValue(headers['phone']);
            final gst = getValue(headers['gst']);

            // Insert
            try {
              await db.into(db.customers).insert(
                    CustomersCompanion(
                      id: drift.Value(
                          '${DateTime.now().millisecondsSinceEpoch}_${i}_${importedCount}'),
                      shopName: drift.Value(name),
                      place: drift.Value(place.isEmpty ? null : place),
                      phone: drift.Value(phone.isEmpty ? null : phone),
                      tinGst: drift.Value(gst.isEmpty ? null : gst),
                      updatedAt: drift.Value(DateTime.now()),
                    ),
                  );
              importedCount++;
            } catch (k) {
              skippedCount++; // Likely duplicate or error
            }
          }
        }
      });

      return {
        'success': true,
        'count': importedCount,
        'skipped': skippedCount,
        'message': 'Imported $importedCount customers ($skippedCount skipped)'
      };
    } catch (e) {
      return {'success': false, 'message': 'Import Failed: $e'};
    }
  }
}
