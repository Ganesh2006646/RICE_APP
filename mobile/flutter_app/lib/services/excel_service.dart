import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';

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

    // --- TABLE HEADERS (13 Columns mapped to indices 0-12) ---
    // Column Index Mapping:
    // 0: SL | 1: PARTY NAME | 2: PLACE | 3: TIN / GST | 4: CELL | 5: TYPE OF RICE
    // 6: 26 KG BAGS | 7: 26 KG QTL | 8: 10 KG QTL | 9: 5 KG QTL | 10: TOTAL QTL | 11: RATE | 12: AMC (1%) | 13: GST | 14: EX INFO

    // Row 4: Main Header
    final mainHeaders = [
      'SL',
      'PARTY NAME',
      'PLACE',
      'TIN / GST',
      'CELL',
      'TYPE OF RICE',
      '26 KG',
      '26 KG',
      '10 KG',
      '5 KG',
      'QTL',
      'AMC',
      'GST',
      'EX INFO'
    ];
    // Note: We'll actually use 14 columns to satisfy the "2 sub-columns for 26kg" requirement.

    for (int i = 0; i < mainHeaders.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      cell.value = TextCellValue(mainHeaders[i]);
      cell.cellStyle = headerStyle;
    }
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 3),
        CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 3));

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
      'RATE',
      '1%',
      '5%',
      ''
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
      10.0,
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

        // Calculations
        final qtl26 = (item.bags26 * 26) / 100.0;
        final qtl10 = (item.bags10 * 10) / 100.0;
        final qtl5 = (item.bags5 * 5) / 100.0;

        // AMC is 1% fixed as per provided logic
        final gstRate = item.gstPercent;
        final exInfo = item.netAmount;

        final rowData = [
          isFirstRow ? slNo.toString() : '-', // 0: SL
          isFirstRow ? (customer.shopName) : '-', // 1: PARTY NAME
          isFirstRow ? (customer.place ?? '-') : '-', // 2: PLACE
          isFirstRow ? (customer.tinGst ?? '-') : '-', // 3: TIN / GST
          isFirstRow ? (customer.phone ?? '-') : '-', // 4: CELL
          product.name, // 5: TYPE OF RICE
          item.bags26 > 0 ? item.bags26.toString() : '-', // 6: 26 KG BAGS
          qtl26 > 0 ? qtl26.toStringAsFixed(2) : '-', // 7: 26 KG QTL
          qtl10 > 0 ? qtl10.toStringAsFixed(2) : '-', // 8: 10 KG QTL
          qtl5 > 0 ? qtl5.toStringAsFixed(2) : '-', // 9: 5 KG QTL
          item.ratePerQtl > 0
              ? item.ratePerQtl.toStringAsFixed(0)
              : '-', // 10: RATE (Under QTL header)
          '1%', // 11: AMC (Under AMC header)
          '${gstRate.toStringAsFixed(0)}%', // 12: GST (Under GST header)
          exInfo.toStringAsFixed(2), // 13: EX INFO
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
  static Future<String> getDownloadsPath() async {
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
  static Future<String> copyToDownloads(String sourcePath) async {
    final sourceFile = File(sourcePath);
    final downloadsPath = await getDownloadsPath();
    final fileName = sourcePath.split('/').last;
    final destPath = '$downloadsPath/$fileName';

    await sourceFile.copy(destPath);
    return destPath;
  }
}
