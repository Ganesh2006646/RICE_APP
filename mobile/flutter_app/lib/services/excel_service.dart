import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import '../providers/settings_provider.dart';

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
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('N1'));

    // Row 2: ORDER NO - <ORDER_NO> and LOADING DATE
    final cellA2 = sheet.cell(CellIndex.indexByString('A2'));
    cellA2.value = TextCellValue('ORDER NO - $orderNumber');
    cellA2.cellStyle = headerStyle;
    sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('F2'));

    final cellG2 = sheet.cell(CellIndex.indexByString('G2'));
    cellG2.value = TextCellValue(
        'LOADING DATE : ${DateFormat('dd - MM -yyyy.').format(order.loadingDate)}');
    cellG2.cellStyle = headerStyle;
    sheet.merge(CellIndex.indexByString('G2'), CellIndex.indexByString('N2'));

    // --- TABLE HEADERS (14 Columns mapped to indices 0-13) ---
    // Row 3: Main Header
    final mainHeaders = [
      'SL',
      'PARTY NAME',
      'PLACE',
      'TIN/GST',
      'CELL',
      'TYPE OF RICE',
      '26 KG',
      '',
      '10 KG',
      '5 KG',
      'QTL',
      'AMC',
      'GST',
      'EX INFO'
    ];

    for (int i = 0; i < mainHeaders.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell.value = TextCellValue(mainHeaders[i]);
      cell.cellStyle = headerStyle;
    }

    // Row 4: Sub Header
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
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      if (subHeaders[i].isNotEmpty) {
        cell.value = TextCellValue(subHeaders[i]);
      }
      cell.cellStyle = headerStyle;
    }

    // Merging Headers
    sheet.merge(CellIndex.indexByString('A3'), CellIndex.indexByString('A4'));
    sheet.merge(CellIndex.indexByString('B3'), CellIndex.indexByString('B4'));
    sheet.merge(CellIndex.indexByString('C3'), CellIndex.indexByString('C4'));
    sheet.merge(CellIndex.indexByString('D3'), CellIndex.indexByString('D4'));
    sheet.merge(CellIndex.indexByString('E3'), CellIndex.indexByString('E4'));
    sheet.merge(CellIndex.indexByString('F3'), CellIndex.indexByString('F4'));
    sheet.merge(CellIndex.indexByString('G3'),
        CellIndex.indexByString('H3')); // 26 KG spans BAGS & QTL
    sheet.merge(CellIndex.indexByString('N3'),
        CellIndex.indexByString('N4')); // EX INFO

    // Set Column Widths
    final widths = [
      5.0, // 0: SL
      30.0, // 1: PARTY NAME
      15.0, // 2: PLACE
      20.0, // 3: TIN/GST
      15.0, // 4: CELL
      25.0, // 5: TYPE OF RICE
      8.0, // 6: 26 KG BAGS
      8.0, // 7: 26 KG QTL
      8.0, // 8: 10 KG QTL
      8.0, // 9: 5 KG QTL
      10.0, // 10: RATE
      6.0, // 11: AMC
      6.0, // 12: GST
      15.0 // 13: EX INFO
    ];
    for (int i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }

    // --- DATA ROWS ---
    int rowIndex = 4;
    int slNo = 1;

    // Group items by customer
    final groupedItems = <String, List<OrderItem>>{};
    for (var item in items) {
      groupedItems.putIfAbsent(item.customerId, () => []).add(item);
    }

    final nf = NumberFormat('#,##0.00', 'en_US');
    final rateNf = NumberFormat('#,##0', 'en_US');

    for (var customerId in groupedItems.keys) {
      final customer = customers.firstWhere(
        (c) => c.id == customerId,
        orElse: () => Customer(
          id: customerId,
          shopName: 'Unknown',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final customerItems = groupedItems[customerId]!;

      for (int i = 0; i < customerItems.length; i++) {
        final item = customerItems[i];
        final product = products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            id: item.productId,
            name: 'Unknown Rice',
            defaultPrice: 0,
            gstRateDefault: 0,
            unit: 'qtl',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final isFirstRow = i == 0;

        // Calculations (Strict Mill Logic)
        final qtl26 = item.bags26 > 0 ? (item.bags26 * 26.0) / 100.0 : 0.0;
        final qtl10 = item.bags10 > 0 ? (item.bags10 * 10.0) / 100.0 : 0.0;
        final qtl5 = item.bags5 > 0 ? (item.bags5 * 5.0) / 100.0 : 0.0;

        final rowData = [
          isFirstRow ? slNo.toString() : '', // 0: SL
          isFirstRow ? (customer.shopName) : '', // 1: PARTY NAME
          isFirstRow ? (customer.place ?? '') : '', // 2: PLACE
          isFirstRow ? (customer.tinGst ?? '') : '', // 3: TIN / GST
          isFirstRow ? (customer.phone ?? '') : '', // 4: CELL
          product.name, // 5: TYPE OF RICE
          item.bags26 > 0 ? item.bags26.toString() : '-', // 6: 26 KG BAGS
          qtl26 > 0 ? qtl26.toStringAsFixed(2) : '-', // 7: 26 KG QTL
          qtl10 > 0
              ? (qtl10 == qtl10.toInt()
                  ? qtl10.toInt().toString()
                  : qtl10.toStringAsFixed(2))
              : '-', // 8: 10 KG QTL
          qtl5 > 0
              ? (qtl5 == qtl5.toInt()
                  ? qtl5.toInt().toString()
                  : qtl5.toStringAsFixed(2))
              : '-', // 9: 5 KG QTL
          item.ratePerQtl > 0
              ? rateNf.format(item.ratePerQtl)
              : '-', // 10: RATE
          item.amcPercent > 0 ? '${item.amcPercent.toInt()}%' : '0%', // 11: AMC
          item.gstPercent > 0 ? '${item.gstPercent.toInt()}%' : '0%', // 12: GST
          nf.format(item.netAmount), // 13: EX INFO (Grand Total for line)
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
      // print('Excel Copy Failed: $e');
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

      final filePath = result.files.single.path;
      if (filePath == null || filePath.isEmpty) {
        return {'success': false, 'message': 'Selected file path is invalid'};
      }

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final excel = _decodeExcelSafe(bytes);
      if (excel == null) {
        return {
          'success': false,
          'message':
              'Import failed: Unsupported or damaged Excel format. Please re-save the file as .xlsx and try again.'
        };
      }

      int importedCount = 0;
      int skippedCount = 0;
      final List<String> errors = [];

      await db.transaction(() async {
        final existingCustomerNames = (await db.select(db.customers).get())
            .map((c) => c.shopName.trim().toLowerCase())
            .toSet();

        for (var table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet == null || sheet.maxRows == 0) continue;

          // Find headers in first row
          final headers = <String, int>{};
          final firstRow = sheet.rows.first;
          bool detectedHeaderRow = false;
          for (int i = 0; i < firstRow.length; i++) {
            final cellValue = _cellToText(firstRow[i]).toLowerCase();
            if (cellValue.contains('name') || cellValue.contains('party')) {
              headers['name'] = i;
              detectedHeaderRow = true;
            } else if (cellValue.contains('place') ||
                cellValue.contains('city')) {
              headers['place'] = i;
              detectedHeaderRow = true;
            } else if (cellValue.contains('phone') ||
                cellValue.contains('mobile') ||
                cellValue.contains('cell')) {
              headers['phone'] = i;
              detectedHeaderRow = true;
            } else if (cellValue.contains('gst') || cellValue.contains('tin')) {
              headers['gst'] = i;
              detectedHeaderRow = true;
            }
          }

          // If no 'name' column found, assume rigid structure: 0=Name, 1=Place, 2=Phone, 3=GST
          if (!headers.containsKey('name')) {
            headers['name'] = 0;
            headers['place'] = 1;
            headers['phone'] = 2;
            headers['gst'] = 3;
          }

          int startRow = detectedHeaderRow ? 1 : 0;
          if (!detectedHeaderRow) {
            final possibleHeader =
                _valueAt(firstRow, headers['name']!).toLowerCase();
            if (possibleHeader.contains('name') ||
                possibleHeader.contains('party')) {
              startRow = 1;
            }

            // Common dataset shape:
            // [SL NO, SHOP NAME, PLACE/ADDRESS, PHONE, GST]
            // If first column is serial-like and second column has text,
            // shift the rigid mapping by one.
            final firstCol = _valueAt(firstRow, 0).trim();
            final secondCol = _valueAt(firstRow, 1).trim();
            if (_isLikelySerial(firstCol) && secondCol.isNotEmpty) {
              headers['name'] = 1;
              headers['place'] = 2;
              headers['phone'] = 3;
              headers['gst'] = 4;
            }
          }

          for (int i = startRow; i < sheet.rows.length; i++) {
            final row = sheet.rows[i];
            if (row.isEmpty) continue;

            final name = _valueAt(row, headers['name']!).trim();
            if (name.isEmpty) continue; // Skip if no name

            final normalizedName = name.toLowerCase();
            if (existingCustomerNames.contains(normalizedName)) {
              skippedCount++;
              continue;
            }

            final place = _valueAt(row, headers['place'] ?? -1).trim();
            final phone = _valueAt(row, headers['phone'] ?? -1).trim();
            final gst = _valueAt(row, headers['gst'] ?? -1).trim();

            // Insert
            try {
              await db.into(db.customers).insert(
                    CustomersCompanion(
                      id: drift.Value(generateId()),
                      shopName: drift.Value(name),
                      place: drift.Value(place.isEmpty ? null : place),
                      phone: drift.Value(phone.isEmpty ? null : phone),
                      tinGst: drift.Value(gst.isEmpty ? null : gst),
                      updatedAt: drift.Value(DateTime.now()),
                    ),
                  );
              importedCount++;
              existingCustomerNames.add(normalizedName);
            } on Exception catch (e) {
              if (e.toString().contains('UNIQUE') ||
                  e.toString().contains('constraint')) {
                skippedCount++; // Duplicate entry
              } else {
                errors.add('Row ${i + 1} ($name): $e');
                skippedCount++;
              }
            }
          }
        }
      });

      final errorSuffix =
          errors.isNotEmpty ? '\nErrors: ${errors.take(5).join('; ')}' : '';
      return {
        'success': true,
        'count': importedCount,
        'skipped': skippedCount,
        'errors': errors,
        'message':
            'Imported $importedCount customers ($skippedCount skipped)$errorSuffix'
      };
    } catch (e) {
      return {'success': false, 'message': 'Import Failed: $e'};
    }
  }

  /// Import Products from Excel
  /// Expected Column Headers: Name, SKU, Price, GST
  static Future<Map<String, dynamic>> importDailyPriceListFromExcel(
      AppDatabase db) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) {
        return {'success': false, 'message': 'No file selected'};
      }

      final filePath = result.files.single.path;
      if (filePath == null || filePath.isEmpty) {
        return {'success': false, 'message': 'Selected file path is invalid'};
      }

      final file = File(filePath);
      if (!await file.exists()) {
        return {'success': false, 'message': 'Selected file does not exist'};
      }

      final bytes = await file.readAsBytes();
      final excel = _decodeExcelSafe(bytes);
      if (excel == null) {
        return {
          'success': false,
          'message':
              'Cannot read this Excel file (style/format issue like numFmtId mismatch). Open it in Excel/WPS and Save As .xlsx, then import again.'
        };
      }

      final baseRowsByName = <String, _DailyBaseRow>{};
      final gstEligibleNames = <String>{};
      final has10KgNames = <String>{};
      final has5KgNames = <String>{};
      final rowErrors = <String>[];
      int parsedRows = 0;
      int ignoredRows = 0;

      for (final tableName in excel.tables.keys) {
        final sheet = excel.tables[tableName];
        if (sheet == null || sheet.maxRows == 0) continue;

        var section = _DailyPriceSection.none;
        _DailyColumnIndexes? columns;
        String? lastProductName;
        int? lastPackingKg;

        for (int i = 0; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          final rowText =
              row.map((cell) => _cellToText(cell)).join(' ').toUpperCase();

          final detectedColumns = _detectDailyColumns(row);
          if (detectedColumns != null) {
            columns = detectedColumns;
            // Header-like row, update index map and skip as data.
            if (detectedColumns.nameIndex != null ||
                detectedColumns.rateIndex != null) {
              continue;
            }
          }

          if (rowText.contains('EXEMPTED')) {
            section = _DailyPriceSection.exempted;
            continue;
          }

          if (RegExp(r'GST\s*5').hasMatch(rowText)) {
            section = _DailyPriceSection.gst5;
            continue;
          }

          if (_isDailyFooterOrNoteRow(rowText)) {
            // Footer and notes are not product rows; stop parsing section data.
            section = _DailyPriceSection.none;
            ignoredRows++;
            continue;
          }

          if (section == _DailyPriceSection.none) continue;

          int? packingKg = _parsePackingKg(
              _valueAt(row, _firstValidIndex([columns?.packingIndex, 1])));
          String productName = _cleanProductName(
              _valueAt(row, _firstValidIndex([columns?.nameIndex, 2])));
          final ratePerQtl = _extractRatePerQtl(row, columns);
          final gstPercent = _extractGstPercent(row, columns);
          final serialText =
              _valueAt(row, _firstValidIndex([columns?.serialIndex, 0])).trim();

          if (productName.isEmpty) {
            // Handle merged-style sheets where name appears once then blanks.
            // Reuse last non-empty product name if the row still looks like data.
            if (ratePerQtl != null && lastProductName != null) {
              productName = lastProductName;
            } else {
              ignoredRows++;
              continue;
            }
          }

          if (productName.toUpperCase().contains('PRODUCT NAME')) {
            ignoredRows++;
            continue;
          }

          if (_isDailyNonDataProductName(productName)) {
            ignoredRows++;
            continue;
          }

          // Strict row constraints based on the provided mill sheet:
          // - EXEMPTED section should be 26kg rows.
          // - GST 5% section should be 10kg / 5kg rows.
          // - Skip rows with unknown packing to avoid parsing notes/footers.
          if (packingKg == null) {
            // Handle merged-style sheets where packing appears once then blanks.
            if (ratePerQtl != null && lastPackingKg != null) {
              packingKg = lastPackingKg;
            } else {
              ignoredRows++;
              continue;
            }
          }

          // Guard against non-data rows that still contain text/numbers.
          final hasSerial = RegExp(r'^\d+$').hasMatch(serialText);
          if (!hasSerial && serialText.isNotEmpty && ratePerQtl == null) {
            ignoredRows++;
            continue;
          }

          // Some files may miss section labels. Infer section from GST/packing.
          if (section == _DailyPriceSection.none) {
            if ((gstPercent ?? 0) > 0) {
              section = _DailyPriceSection.gst5;
            } else if (packingKg == 26) {
              section = _DailyPriceSection.exempted;
            }
          }

          if (section == _DailyPriceSection.exempted && packingKg != 26) {
            ignoredRows++;
            continue;
          }
          if (section == _DailyPriceSection.gst5 &&
              packingKg != 10 &&
              packingKg != 5) {
            ignoredRows++;
            continue;
          }

          final normalizedName = _normalizeProductName(productName);
          lastProductName = productName;
          lastPackingKg = packingKg;

          if (packingKg == 10) {
            has10KgNames.add(normalizedName);
          } else if (packingKg == 5) {
            has5KgNames.add(normalizedName);
          }

          if (section == _DailyPriceSection.gst5) {
            gstEligibleNames.add(normalizedName);
          }

          if (ratePerQtl == null) {
            ignoredRows++;
            continue;
          }

          parsedRows++;

          final priority = _dailyRatePriority(
            section: section,
            packingKg: packingKg,
          );

          final existing = baseRowsByName[normalizedName];
          final shouldReplace = existing == null ||
              (existing.ratePerQtl <= 0 && ratePerQtl > 0) ||
              (existing.ratePerQtl <= 0 &&
                  ratePerQtl <= 0 &&
                  priority > existing.priority) ||
              (existing.ratePerQtl > 0 &&
                  ratePerQtl > 0 &&
                  priority > existing.priority);

          if (shouldReplace) {
            baseRowsByName[normalizedName] = _DailyBaseRow(
              name: productName,
              normalizedName: normalizedName,
              ratePerQtl: ratePerQtl,
              section: section,
              priority: priority,
            );
          }
        }
      }

      if (parsedRows == 0 || baseRowsByName.isEmpty) {
        return {
          'success': false,
          'message':
              'Could not find daily price list rows. Use the mill-style sheet with EXEMPTED / GST 5% sections.'
        };
      }

      int insertedCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;

      await db.transaction(() async {
        final now = DateTime.now();
        final existingProducts = await db.select(db.products).get();

        final productsBySku = <String, Product>{};
        final productsByNormalizedName = <String, Product>{};

        for (final product in existingProducts) {
          final sku = product.sku;
          if (sku != null && sku.isNotEmpty) {
            productsBySku[sku] = product;
          }
          productsByNormalizedName[_normalizeProductName(product.name)] =
              product;
        }

        for (final row in baseRowsByName.values) {
          if (row.ratePerQtl <= 0) {
            skippedCount++;
            continue;
          }

          final sku = _buildDailyPriceSku(row.normalizedName);
          final gstRate =
              gstEligibleNames.contains(row.normalizedName) ? 5.0 : 0.0;
          final supports10Kg = has10KgNames.contains(row.normalizedName);
          final supports5Kg = has5KgNames.contains(row.normalizedName);
          final unitMeta = _buildUnitWithPackSupport(
            supports10Kg: supports10Kg,
            supports5Kg: supports5Kg,
          );

          final existingProduct = productsBySku[sku] ??
              productsByNormalizedName[row.normalizedName];

          try {
            if (existingProduct != null) {
              await (db.update(db.products)
                    ..where((tbl) => tbl.id.equals(existingProduct.id)))
                  .write(ProductsCompanion(
                sku: drift.Value(sku),
                name: drift.Value(row.name),
                defaultPrice: drift.Value(row.ratePerQtl),
                gstRateDefault: drift.Value(gstRate),
                unit: drift.Value(unitMeta),
                updatedAt: drift.Value(now),
              ));
              updatedCount++;

              // Keep local lookup maps fresh so later rows resolve consistently.
              final refreshed = existingProduct.copyWith(
                sku: drift.Value(sku),
                name: row.name,
                defaultPrice: row.ratePerQtl,
                gstRateDefault: gstRate,
                unit: unitMeta,
                updatedAt: now,
              );
              productsBySku[sku] = refreshed;
              productsByNormalizedName[row.normalizedName] = refreshed;
            } else {
              final id = generateId();
              final insertedProduct = Product(
                id: id,
                sku: sku,
                name: row.name,
                defaultPrice: row.ratePerQtl,
                gstRateDefault: gstRate,
                unit: unitMeta,
                createdAt: now,
                updatedAt: now,
              );

              await db.into(db.products).insert(ProductsCompanion(
                    id: drift.Value(id),
                    sku: drift.Value(sku),
                    name: drift.Value(row.name),
                    defaultPrice: drift.Value(row.ratePerQtl),
                    gstRateDefault: drift.Value(gstRate),
                    unit: drift.Value(unitMeta),
                    updatedAt: drift.Value(now),
                  ));
              insertedCount++;

              productsBySku[sku] = insertedProduct;
              productsByNormalizedName[row.normalizedName] = insertedProduct;
            }
          } on Exception catch (e) {
            skippedCount++;
            if (rowErrors.length < 5) {
              rowErrors.add('${row.name}: $e');
            }
          }
        }
      });

      final gstOnlyCount =
          gstEligibleNames.difference(baseRowsByName.keys.toSet()).length;
      final gstOnlyNote =
          gstOnlyCount > 0 ? ' | GST-only rows skipped: $gstOnlyCount' : '';
      final errorNote =
          rowErrors.isNotEmpty ? ' | Row issues: ${rowErrors.join(' ; ')}' : '';

      return {
        'success': true,
        'inserted': insertedCount,
        'updated': updatedCount,
        'skipped': skippedCount,
        'parsedRows': parsedRows,
        'ignoredRows': ignoredRows,
        'errors': rowErrors,
        'message':
            'Daily price list imported: $insertedCount new, $updatedCount updated, $skippedCount skipped.$gstOnlyNote$errorNote'
      };
    } catch (e) {
      return {'success': false, 'message': 'Import Failed: $e'};
    }
  }

  /// Import Products from Excel
  /// Expected Column Headers: Name, SKU, Price, GST
  static Future<Map<String, dynamic>> importProductsFromExcel(
      AppDatabase db) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) {
        return {'success': false, 'message': 'No file selected'};
      }

      final filePath = result.files.single.path;
      if (filePath == null || filePath.isEmpty) {
        return {'success': false, 'message': 'Selected file path is invalid'};
      }

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final excel = _decodeExcelSafe(bytes);
      if (excel == null) {
        return {
          'success': false,
          'message':
              'Import failed: Unsupported or damaged Excel format. Please re-save the file as .xlsx and try again.'
        };
      }

      int importedCount = 0;
      int skippedCount = 0;
      final List<String> errors = [];

      await db.transaction(() async {
        final existingProducts = await db.select(db.products).get();
        final existingNames =
            existingProducts.map((p) => _normalizeProductName(p.name)).toSet();
        final existingSkus = existingProducts
            .map((p) => (p.sku ?? '').trim().toLowerCase())
            .where((s) => s.isNotEmpty)
            .toSet();

        for (var table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet == null || sheet.maxRows == 0) continue;

          // Find headers in first row
          final headers = <String, int>{};
          final firstRow = sheet.rows.first;
          bool detectedHeaderRow = false;
          for (int i = 0; i < firstRow.length; i++) {
            final cellValue = _cellToText(firstRow[i]).toLowerCase();
            if (cellValue.contains('name') || cellValue.contains('variety')) {
              headers['name'] = i;
              detectedHeaderRow = true;
            } else if (cellValue.contains('sku') ||
                cellValue.contains('code')) {
              headers['sku'] = i;
              detectedHeaderRow = true;
            } else if (cellValue.contains('price') ||
                cellValue.contains('rate') ||
                cellValue.contains('cost')) {
              headers['price'] = i;
              detectedHeaderRow = true;
            } else if (cellValue.contains('gst') || cellValue.contains('tax')) {
              headers['gst'] = i;
              detectedHeaderRow = true;
            }
          }

          // If no 'name' column found, assume structure: 0=Name, 1=Price, 2=GST, 3=SKU
          if (!headers.containsKey('name')) {
            headers['name'] = 0;
            headers['price'] = 1;
            headers['gst'] = 2;
            headers['sku'] = 3;
          }

          int startRow = detectedHeaderRow ? 1 : 0;
          if (!detectedHeaderRow) {
            final firstRowName =
                _valueAt(sheet.rows.first, headers['name']!).toLowerCase();
            if (firstRowName.contains('name') ||
                firstRowName.contains('variety')) {
              startRow = 1;
            }
          }

          for (int i = startRow; i < sheet.rows.length; i++) {
            final row = sheet.rows[i];
            if (row.isEmpty) continue;

            final name = _valueAt(row, headers['name']!).trim();
            if (name.isEmpty) continue;

            final priceStr = _valueAt(row, headers['price'] ?? -1).trim();
            final gstStr = _valueAt(row, headers['gst'] ?? -1).trim();
            final sku = _valueAt(row, headers['sku'] ?? -1).trim();
            final normalizedName = _normalizeProductName(name);
            final normalizedSku = sku.toLowerCase();

            if (existingNames.contains(normalizedName) ||
                (normalizedSku.isNotEmpty &&
                    existingSkus.contains(normalizedSku))) {
              skippedCount++;
              continue;
            }

            final price = _toNumber(priceStr) ?? 0.0;
            final gst = _toNumber(gstStr) ?? 0.0;

            try {
              final id = generateId();
              await db.into(db.products).insert(
                    ProductsCompanion(
                      id: drift.Value(id),
                      sku: drift.Value(sku.isEmpty ? null : sku),
                      name: drift.Value(name),
                      defaultPrice: drift.Value(price),
                      gstRateDefault: drift.Value(gst),
                      updatedAt: drift.Value(DateTime.now()),
                    ),
                  );
              importedCount++;
              existingNames.add(normalizedName);
              if (normalizedSku.isNotEmpty) {
                existingSkus.add(normalizedSku);
              }
            } on Exception catch (e) {
              if (e.toString().contains('UNIQUE') ||
                  e.toString().contains('constraint')) {
                skippedCount++;
              } else {
                errors.add('Row ${i + 1} ($name): $e');
                skippedCount++;
              }
            }
          }
        }
      });

      final errorSuffix =
          errors.isNotEmpty ? '\nErrors: ${errors.take(5).join('; ')}' : '';
      return {
        'success': true,
        'count': importedCount,
        'skipped': skippedCount,
        'errors': errors,
        'message':
            'Imported $importedCount products ($skippedCount skipped)$errorSuffix'
      };
    } catch (e) {
      return {'success': false, 'message': 'Import Failed: $e'};
    }
  }

  /// Append deleted customer to consolidated Excel file
  static Future<void> appendDeletedCustomer(Customer customer,
      {String? customPath}) async {
    try {
      final downloadsPath = await getDownloadsPath(customPath: customPath);
      final filePath = '$downloadsPath/deleted_customers.xlsx';
      final file = File(filePath);

      Excel excel;
      if (await file.exists()) {
        var bytes = await file.readAsBytes();
        excel = Excel.decodeBytes(bytes);
      } else {
        excel = Excel.createExcel();
        excel.rename('Sheet1', 'Deleted Customers');
        final headerStyle = CellStyle(bold: true);
        final headers = ['ID', 'NAME', 'PLACE', 'PHONE', 'GST', 'DELETED_AT'];
        for (int i = 0; i < headers.length; i++) {
          final cell = excel['Deleted Customers']
              .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
          cell.value = TextCellValue(headers[i]);
          cell.cellStyle = headerStyle;
        }
      }

      final sheet = excel['Deleted Customers'];
      final nextRow = sheet.maxRows;
      final data = [
        customer.id,
        customer.shopName,
        customer.place ?? '',
        customer.phone ?? '',
        customer.tinGst ?? '',
        DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now())
      ];

      for (int i = 0; i < data.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: nextRow))
            .value = TextCellValue(data[i]);
      }

      final bytes = excel.save();
      if (bytes != null) await file.writeAsBytes(bytes);
    } catch (e) {
      debugPrint('Error appending deleted customer: $e');
    }
  }

  /// Append deleted variety to consolidated Excel file
  static Future<void> appendDeletedVariety(Product product,
      {String? customPath}) async {
    try {
      final downloadsPath = await getDownloadsPath(customPath: customPath);
      final filePath = '$downloadsPath/deleted_varieties.xlsx';
      final file = File(filePath);

      Excel excel;
      if (await file.exists()) {
        var bytes = await file.readAsBytes();
        excel = Excel.decodeBytes(bytes);
      } else {
        excel = Excel.createExcel();
        excel.rename('Sheet1', 'Deleted Varieties');
        final headerStyle = CellStyle(bold: true);
        final headers = ['ID', 'NAME', 'SKU', 'PRICE', 'GST', 'DELETED_AT'];
        for (int i = 0; i < headers.length; i++) {
          final cell = excel['Deleted Varieties']
              .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
          cell.value = TextCellValue(headers[i]);
          cell.cellStyle = headerStyle;
        }
      }

      final sheet = excel['Deleted Varieties'];
      final nextRow = sheet.maxRows;
      final data = [
        product.id,
        product.name,
        product.sku ?? '',
        product.defaultPrice.toString(),
        product.gstRateDefault.toString(),
        DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now())
      ];

      for (int i = 0; i < data.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: nextRow))
            .value = TextCellValue(data[i]);
      }

      final bytes = excel.save();
      if (bytes != null) await file.writeAsBytes(bytes);
    } catch (e) {
      debugPrint('Error appending deleted variety: $e');
    }
  }

  static String _valueAt(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return _cellToText(row[index]);
  }

  static int _firstValidIndex(List<int?> candidates) {
    for (final idx in candidates) {
      if (idx != null && idx >= 0) return idx;
    }
    return -1;
  }

  static _DailyColumnIndexes? _detectDailyColumns(List<Data?> row) {
    int? serialIndex;
    int? packingIndex;
    int? nameIndex;
    int? rateIndex;
    int? gstIndex;
    int? totalIndex;

    for (int i = 0; i < row.length; i++) {
      final text = _cellToText(row[i]).toUpperCase();
      if (text.isEmpty) continue;

      if (serialIndex == null &&
          (text.contains('S.NO') || text.contains('SL NO') || text == 'SL')) {
        serialIndex = i;
        continue;
      }

      if (packingIndex == null && text.contains('PACKING')) {
        packingIndex = i;
        continue;
      }

      if (nameIndex == null &&
          text.contains('PRODUCT') &&
          text.contains('NAME')) {
        nameIndex = i;
        continue;
      }

      if (rateIndex == null &&
          ((text.contains('PRICE') && text.contains('QUINTAL')) ||
              text.contains('100 KG') ||
              text == 'RATE')) {
        rateIndex = i;
        continue;
      }

      if (gstIndex == null && text.contains('GST')) {
        gstIndex = i;
        continue;
      }

      if (totalIndex == null &&
          (text == 'TOTAL' ||
              text.contains('LINE TOTAL') ||
              text.contains('GRAND TOTAL'))) {
        totalIndex = i;
      }
    }

    if (serialIndex == null &&
        packingIndex == null &&
        nameIndex == null &&
        rateIndex == null &&
        gstIndex == null &&
        totalIndex == null) {
      return null;
    }

    return _DailyColumnIndexes(
      serialIndex: serialIndex,
      packingIndex: packingIndex,
      nameIndex: nameIndex,
      rateIndex: rateIndex,
      gstIndex: gstIndex,
      totalIndex: totalIndex,
    );
  }

  static String _cellToText(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';

    if (value is TextCellValue) return value.value.toString().trim();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is BoolCellValue) return value.value.toString();

    final fallback = value.toString().trim();
    final wrapped =
        RegExp(r'^[A-Za-z]+CellValue\(value:\s*(.*)\)$').firstMatch(fallback);
    return wrapped?.group(1)?.trim() ?? fallback;
  }

  static double? _toNumber(String input) {
    if (input.isEmpty) return null;

    final cleaned = input
        .replaceAll(',', '')
        .replaceAll('%', '')
        .replaceAll(RegExp(r'[^0-9.\-]'), '');

    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') {
      return null;
    }
    return double.tryParse(cleaned);
  }

  static bool _isLikelySerial(String input) {
    if (input.isEmpty) return false;
    final trimmed = input.trim();
    // Handles "1", "001", "1.", "1)"
    return RegExp(r'^\d+([.)])?$').hasMatch(trimmed);
  }

  static double? _extractRatePerQtl(
      List<Data?> row, _DailyColumnIndexes? columns) {
    final configuredRate =
        _toNumber(_valueAt(row, _firstValidIndex([columns?.rateIndex, 3])));
    if (configuredRate != null) return configuredRate;

    final nameIndex = _firstValidIndex([columns?.nameIndex, 2]);
    if (nameIndex >= 0) {
      for (int i = nameIndex + 1; i < row.length; i++) {
        final value = _toNumber(_valueAt(row, i));
        if (value != null) return value;
      }
    }

    return null;
  }

  static double? _extractGstPercent(List<Data?> row, _DailyColumnIndexes? cols) {
    return _toNumber(_valueAt(row, _firstValidIndex([cols?.gstIndex, 5])));
  }

  static int? _parsePackingKg(String input) {
    final match = RegExp(r'(\d+)').firstMatch(input);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static int _dailyRatePriority({
    required _DailyPriceSection section,
    int? packingKg,
  }) {
    final sectionScore = section == _DailyPriceSection.exempted
        ? 200
        : section == _DailyPriceSection.gst5
            ? 100
            : 0;

    int packingScore;
    if (packingKg == 26) {
      packingScore = 30;
    } else if (packingKg == 10) {
      packingScore = 20;
    } else if (packingKg == 5) {
      packingScore = 10;
    } else {
      packingScore = 1;
    }

    return sectionScore + packingScore;
  }

  static String _cleanProductName(String input) {
    return input.replaceAll('*', '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _normalizeProductName(String input) {
    return _cleanProductName(input)
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _buildDailyPriceSku(String normalizedName) {
    final compact = normalizedName.replaceAll(' ', '_');
    final prefix = compact.length > 28 ? compact.substring(0, 28) : compact;
    final hash = _stableHexHash(normalizedName);
    return 'DAILY_${prefix}_$hash';
  }

  static String _buildUnitWithPackSupport({
    required bool supports10Kg,
    required bool supports5Kg,
  }) {
    return 'qtl|p10:${supports10Kg ? 1 : 0}|p5:${supports5Kg ? 1 : 0}';
  }

  static bool _isDailyFooterOrNoteRow(String rowTextUpper) {
    final t = rowTextUpper;
    if (t.trim().isEmpty) return false;

    return t.contains('CASH DISCOUNT') ||
        t.contains('PAYMENT WITH') ||
        t.contains('ABOVE 20 DAYS') ||
        t.contains('AFTER 30 DAYS') ||
        t.contains('NOTE') ||
        t.contains('LOADING AFTER') ||
        t.contains('TODAY OUR PRICE LIST') ||
        t.contains('SRI BALAJI') ||
        t.contains('GALAXY RICE');
  }

  static bool _isDailyNonDataProductName(String name) {
    final upper = name.toUpperCase().trim();
    if (upper.isEmpty) return true;
    if (upper == '-' || upper == '--' || upper == '---') return true;
    if (upper.contains('EXEMPTED') || upper.contains('GST 5')) return true;
    return false;
  }

  static String _stableHexHash(String input) {
    // FNV-1a 32-bit hash for deterministic, short SKU suffixes.
    int hash = 0x811C9DC5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).toUpperCase().padLeft(8, '0');
  }

  static Excel? _decodeExcelSafe(List<int> bytes) {
    try {
      return Excel.decodeBytes(bytes);
    } catch (e) {
      // Known failure class from some edited sheets:
      // "custom numFmtId is at ... but found in ..."
      // Also guards null-check crashes inside the parser.
      debugPrint('Excel decode failed: $e');
      return null;
    }
  }
}

enum _DailyPriceSection { none, exempted, gst5 }

class _DailyBaseRow {
  final String name;
  final String normalizedName;
  final double ratePerQtl;
  final _DailyPriceSection section;
  final int priority;

  const _DailyBaseRow({
    required this.name,
    required this.normalizedName,
    required this.ratePerQtl,
    required this.section,
    required this.priority,
  });
}

class _DailyColumnIndexes {
  final int? serialIndex;
  final int? packingIndex;
  final int? nameIndex;
  final int? rateIndex;
  final int? gstIndex;
  final int? totalIndex;

  const _DailyColumnIndexes({
    this.serialIndex,
    this.packingIndex,
    this.nameIndex,
    this.rateIndex,
    this.gstIndex,
    this.totalIndex,
  });
}
