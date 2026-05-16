import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
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
  /// Generate Excel file for a multi-customer lorry order.
  /// [settings] is used to apply packing surcharges to the displayed rate
  /// for 10 KG and 5 KG bags (surcharge10kgPerQtl / surcharge5kgPerQtl).
  static Future<String> generateLorryExcel({
    required Order order,
    required List<OrderItem> items,
    required List<Customer> customers,
    required List<Product> products,
    required String orderNumber,
    AppSettings? settings,
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
      if (item.bags26 == 0 && item.bags10 == 0 && item.bags5 == 0) continue;
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
            isGalaxy: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final isFirstRow = i == 0;

        // Packing surcharges from settings (default to stored values if no settings passed)
        final surcharge10 = settings?.surcharge10kgPerQtl ?? 200.0;
        final surcharge5  = settings?.surcharge5kgPerQtl  ?? 250.0;

        // Calculations (Strict Mill Logic)
        final qtl26 = item.bags26 > 0 ? (item.bags26 * 26.0) / 100.0 : 0.0;
        final qtl10 = item.bags10 > 0 ? (item.bags10 * 10.0) / 100.0 : 0.0;
        final qtl5  = item.bags5  > 0 ? (item.bags5  * 5.0)  / 100.0 : 0.0;

        // Effective rate shown in RATE column:
        //  - 26 KG bags: base rate (no surcharge)
        //  - 10 KG bags: base rate + surcharge10kgPerQtl
        //  -  5 KG bags: base rate + surcharge5kgPerQtl
        // For mixed bags, compute a weighted average surcharge.
        final baseRate = item.ratePerQtl;
        double effectiveRate = baseRate;
        final totalKg = item.bags26 * 26.0 + item.bags10 * 10.0 + item.bags5 * 5.0;
        if (totalKg > 0) {
          final surchargePerKg = (item.bags10 * 10.0 * surcharge10 + item.bags5 * 5.0 * surcharge5) / totalKg;
          effectiveRate = baseRate + surchargePerKg;
        }

        final rowData = [
          isFirstRow ? slNo.toString() : '', // 0: SL
          isFirstRow ? (customer.shopName) : '', // 1: PARTY NAME
          isFirstRow ? (customer.place ?? '') : '', // 2: PLACE
          isFirstRow ? (customer.tinGst ?? '') : '', // 3: TIN / GST
          isFirstRow ? _sanitizePhone(customer.phone) : '', // 4: CELL
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
          effectiveRate > 0
              ? rateNf.format(effectiveRate)
              : '-', // 10: RATE (effective = base + surcharge for small packs)
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

  static String _sanitizePhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    String cleaned = phone.trim();
    if (cleaned.endsWith('.0')) cleaned = cleaned.substring(0, cleaned.length - 2);
    if (cleaned.endsWith('.00')) cleaned = cleaned.substring(0, cleaned.length - 3);
    return cleaned;
  }

  /// Get the downloads directory path for the user
  static Future<String> getDownloadsPath({String? customPath}) async {
    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return customPath;
    }

    if (Platform.isAndroid) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final downloadDir = Directory('${directory.path}/exports');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir.path;
      } catch (_) {}
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
            } else if (cellValue.contains('gstin') ||
                cellValue.contains('gst') ||
                cellValue.contains('tin')) {
              // 'gstin' must be checked before 'gst' since 'gstin'.contains('gst')
              // is also true — explicit ordering ensures clarity.
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
            String phone = _valueAt(row, headers['phone'] ?? -1).trim();
            if (phone.endsWith('.0')) phone = phone.substring(0, phone.length - 2);
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
  ///
  /// When [dryRun] is true, the DB is NOT written. Instead, 'preview' key in
  /// the result contains a List<_PriceUpdateResult> so the UI can display a
  /// "Review Changes" confirmation screen before committing.
  static Future<Map<String, dynamic>> importDailyPriceListFromExcel(
      AppDatabase db, {bool dryRun = false}) async {
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
              continue;
            }
          }

          if (productName.toUpperCase().contains('PRODUCT NAME')) {
            continue;
          }

          if (_isDailyNonDataProductName(productName)) {
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
              continue;
            }
          }

          // Guard against non-data rows that still contain text/numbers.
          final hasSerial = RegExp(r'^\d+$').hasMatch(serialText);
          if (!hasSerial && serialText.isNotEmpty && ratePerQtl == null) {
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
            continue;
          }
          if (section == _DailyPriceSection.gst5 &&
              packingKg != 10 &&
              packingKg != 5) {
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

      // PRICE-UPDATE-ONLY MODE:
      // We only update prices for varieties that already exist in the database.
      // We never insert new varieties from the price sheet — the user must add
      // those manually. This prevents ghost entries from header/footer rows.
      int updatedCount = 0;
      int skippedCount = 0; // rate is 0 or no db match found
      final List<_PriceUpdateResult> updateResults = [];

      // Always load existing products for matching (needed for both dry-run and commit).
      final now = DateTime.now();
      final existingProducts = await db.select(db.products).get();

      // Build lookup maps: normalized name → product
      final productsByNormalizedName = <String, Product>{};
      final productsBySku = <String, Product>{};

      for (final product in existingProducts) {
        productsByNormalizedName[_normalizeProductName(product.name)] = product;
        final sku = product.sku;
        if (sku != null && sku.isNotEmpty) {
          productsBySku[sku] = product;
        }
      }

      for (final row in baseRowsByName.values) {
        // Skip zero-price rows (e.g., out-of-stock items with 0.00)
        if (row.ratePerQtl <= 0) {
          updateResults.add(_PriceUpdateResult(
            excelName: row.name,
            status: _UpdateStatus.zeroPriceSkipped,
          ));
          skippedCount++;
          continue;
        }

        // Try to find a matching product in DB
        // 1. Exact normalized name match
        // 2. SKU match (for previously imported varieties)
        // 3. Fuzzy: DB name contains all words from Excel name (or vice versa)
        final sku = _buildDailyPriceSku(row.normalizedName);
        Product? matchedProduct = productsByNormalizedName[row.normalizedName]
            ?? productsBySku[sku]
            ?? _fuzzyMatchProduct(row.normalizedName, productsByNormalizedName);

        if (matchedProduct == null) {
          // Not found in DB: auto-create new product from price sheet
          final newId = generateId();
          final autoGst =
              gstEligibleNames.contains(row.normalizedName) ? 5.0 : 0.0;
          final autoSupports10Kg = has10KgNames.contains(row.normalizedName);
          final autoSupports5Kg = has5KgNames.contains(row.normalizedName);
          final autoUnitMeta = _buildUnitWithPackSupport(
            supports10Kg: autoSupports10Kg,
            supports5Kg: autoSupports5Kg,
          );
          final autoIsGalaxy = row.name.toUpperCase().contains('GALAXY');

          updateResults.add(_PriceUpdateResult(
            excelName: row.name,
            dbName: row.name,
            oldPrice: null,
            newPrice: row.ratePerQtl,
            newGst: autoGst,
            newUnit: autoUnitMeta,
            newSku: sku,
            dbProductId: newId,
            status: _UpdateStatus.pending,
            isNewInsert: true,
          ));
          updatedCount++;

          productsByNormalizedName[row.normalizedName] = Product(
            id: newId,
            name: row.name,
            defaultPrice: row.ratePerQtl,
            gstRateDefault: autoGst,
            unit: autoUnitMeta,
            isGalaxy: autoIsGalaxy,
            createdAt: now,
            updatedAt: now,
          );
          continue;
        }

        final gstRate =
            gstEligibleNames.contains(row.normalizedName) ? 5.0 : 0.0;
        final supports10Kg = has10KgNames.contains(row.normalizedName);
        final supports5Kg = has5KgNames.contains(row.normalizedName);
        final unitMeta = _buildUnitWithPackSupport(
          supports10Kg: supports10Kg,
          supports5Kg: supports5Kg,
        );

        // Record the proposed change (old price vs new price) for the preview.
        updateResults.add(_PriceUpdateResult(
          excelName: row.name,
          dbName: matchedProduct.name,
          oldPrice: matchedProduct.defaultPrice,
          newPrice: row.ratePerQtl,
          newGst: gstRate,
          newUnit: unitMeta,
          newSku: sku,
          dbProductId: matchedProduct.id,
          status: _UpdateStatus.pending, // pending until committed
        ));
        updatedCount++;

        // Keep the preview map fresh for subsequent fuzzy lookups.
        productsByNormalizedName[_normalizeProductName(matchedProduct.name)] =
            matchedProduct.copyWith(defaultPrice: row.ratePerQtl);
      }

      // ── DRY-RUN MODE: return preview without touching DB ─────────────────────
      if (dryRun) {
        final notFoundDry = updateResults
            .where((r) => r.status == _UpdateStatus.notFound)
            .map((r) => r.excelName)
            .toList();
        final zeroDry = updateResults
            .where((r) => r.status == _UpdateStatus.zeroPriceSkipped)
            .map((r) => r.excelName)
            .toList();

        // Convert to the public PriceChangePreview type for the UI.
        final publicPreview = updateResults.map((r) => PriceChangePreview(
          excelName: r.excelName,
          dbName: r.dbName,
          oldPrice: r.oldPrice,
          newPrice: r.newPrice,
          newGst: r.newGst,
          isMatched: r.status == _UpdateStatus.pending,
          isNewInsert: r.isNewInsert,
        )).toList();

        return {
          'success': true,
          'dryRun': true,
          'updated': updatedCount,
          'skipped': skippedCount,
          'parsedRows': parsedRows,
          'notFound': notFoundDry,
          'zeroPriced': zeroDry,
          'errors': rowErrors,
          'preview': publicPreview,   // List<PriceChangePreview> for UI review
          'message': 'Preview ready. $updatedCount ${updatedCount == 1 ? 'variety' : 'varieties'} will be updated.',
        };
      }

      // ── COMMIT MODE: write changes to DB inside a transaction ─────────────────
      await db.transaction(() async {
        for (final r in updateResults) {
          if (r.status != _UpdateStatus.pending) continue;
          final dbId = r.dbProductId;
          if (dbId == null) continue;
          try {
            if (r.isNewInsert) {
              await db.into(db.products).insert(ProductsCompanion(
                id: drift.Value(dbId),
                name: drift.Value(r.dbName ?? r.excelName),
                sku: drift.Value(r.newSku),
                defaultPrice: drift.Value(r.newPrice ?? 0.0),
                gstRateDefault: drift.Value(r.newGst ?? 0.0),
                unit: drift.Value(r.newUnit ?? 'qtl'),
                isGalaxy: drift.Value(r.excelName.toUpperCase().contains('GALAXY')),
                updatedAt: drift.Value(now),
              ));
            } else {
              await (db.update(db.products)
                    ..where((tbl) => tbl.id.equals(dbId)))
                  .write(ProductsCompanion(
                sku: drift.Value(r.newSku),
                defaultPrice: drift.Value(r.newPrice!),
                gstRateDefault: drift.Value(r.newGst ?? 0.0),
                unit: drift.Value(r.newUnit ?? 'qtl'),
                isGalaxy: drift.Value(r.excelName.toUpperCase().contains('GALAXY')),
                updatedAt: drift.Value(now),
              ));
            }
            r.markCommitted();
          } on Exception catch (e) {
            r.markError(e.toString());
            if (rowErrors.length < 5) rowErrors.add('${r.excelName}: $e');
            skippedCount++;
          }
        }
      });

      final committedCount =
          updateResults.where((r) => r.status == _UpdateStatus.updated).length;

      final notFoundList = updateResults
          .where((r) => r.status == _UpdateStatus.notFound)
          .map((r) => r.excelName)
          .toList();

      final zeroList = updateResults
          .where((r) => r.status == _UpdateStatus.zeroPriceSkipped)
          .map((r) => r.excelName)
          .toList();

      return {
        'success': true,
        'updated': committedCount,
        'skipped': skippedCount,
        'parsedRows': parsedRows,
        'notFound': notFoundList,
        'zeroPriced': zeroList,
        'errors': rowErrors,
        'updateResults': updateResults,
        'message': committedCount > 0
            ? '✅ $committedCount ${committedCount == 1 ? 'variety' : 'varieties'} updated'
                '${notFoundList.isNotEmpty ? '\n⚠️ ${notFoundList.length} not found in your database' : ''}'
            : 'No varieties were updated. Check that variety names in the Excel match your database.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Import Failed: $e'};
    }
  }

  /// Fuzzy match: find a DB product whose normalized name shares enough
  /// words with the Excel normalized name (minimum 2 meaningful words).
  static Product? _fuzzyMatchProduct(
      String normalizedExcelName, Map<String, Product> dbMap) {
    final excelWords = normalizedExcelName.split(' ')
        .where((w) => w.length > 2)
        .toSet();
    if (excelWords.length < 2) return null;

    Product? bestMatch;
    int bestScore = 0;

    for (final entry in dbMap.entries) {
      final dbWords = entry.key.split(' ')
          .where((w) => w.length > 2)
          .toSet();
      final shared = excelWords.intersection(dbWords).length;
      if (shared >= 2 && shared > bestScore) {
        bestScore = shared;
        bestMatch = entry.value;
      }
    }
    return bestMatch;
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
                          isGalaxy: drift.Value(name.toUpperCase().contains('GALAXY')),
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
    // Attempt 1: Pre-sanitise styles.xml first (primary path for WPS/LibreOffice
    // files that embed built-in numFmtIds < 164 as custom entries, which crashes
    // the excel package). This is safe for all valid xlsx files.
    try {
      final patched = _patchXlsxStyles(bytes);
      if (patched != null) {
        return Excel.decodeBytes(patched);
      }
    } catch (e) {
      debugPrint('Excel decode attempt 1 (patched) failed: $e');
    }

    // Attempt 2: Fallback — plain decode without patching (for files whose
    // zip structure _patchXlsxStyles cannot parse, e.g. zip64 or encrypted).
    try {
      return Excel.decodeBytes(bytes);
    } catch (e) {
      debugPrint('Excel decode attempt 2 (plain) failed: $e');
    }

    return null;
  }

  /// Patches the xl/styles.xml inside an xlsx (zip) archive to remove
  /// custom numFmt entries whose IDs conflict with built-in Excel IDs (< 164).
  /// Returns the patched bytes, or null if zip manipulation failed.
  static List<int>? _patchXlsxStyles(List<int> bytes) {
    try {
      // An xlsx is a ZIP file. We look for the PK local-file-header signatures
      // to find and patch xl/styles.xml in-place using a simple string substitution.
      // This avoids needing the `archive` package.

      // Convert bytes to string for zip directory scanning
      // We'll work at the raw byte level using a simple ZIP parser.
      final data = Uint8List.fromList(bytes);

      // Find central directory by scanning from end for EOCD signature.
      // Per ZIP spec, EOCD must be within the last 65557 bytes (64KB comment + 22 byte EOCD).
      // Restricting the search prevents false matches in large file data.
      const eocdSig = [0x50, 0x4B, 0x05, 0x06];
      final searchStart = math.max(0, data.length - 65557);
      int eocdOffset = -1;
      for (int i = data.length - 22; i >= searchStart; i--) {
        if (data[i] == eocdSig[0] &&
            data[i + 1] == eocdSig[1] &&
            data[i + 2] == eocdSig[2] &&
            data[i + 3] == eocdSig[3]) {
          eocdOffset = i;
          break;
        }
      }
      if (eocdOffset < 0) return null;

      // Read central directory offset and size from EOCD
      final cdOffset = _readUint32LE(data, eocdOffset + 16);
      final cdSize = _readUint32LE(data, eocdOffset + 12);
      final entryCount = _readUint16LE(data, eocdOffset + 10);

      // Scan central directory entries for xl/styles.xml
      int pos = cdOffset;
      int? stylesLocalOffset;
      int stylesCompressedSize = 0;
      int stylesUncompressedSize = 0;
      int stylesCompressionMethod = 0;

      for (int e = 0; e < entryCount && pos < cdOffset + cdSize; e++) {
        // Central directory signature: PK\x01\x02
        if (data[pos] != 0x50 || data[pos + 1] != 0x4B ||
            data[pos + 2] != 0x01 || data[pos + 3] != 0x02) { break; }

        final compressionMethod = _readUint16LE(data, pos + 10);
        final compressedSize = _readUint32LE(data, pos + 20);
        final uncompressedSize = _readUint32LE(data, pos + 24);
        final fileNameLen = _readUint16LE(data, pos + 28);
        final extraLen = _readUint16LE(data, pos + 30);
        final commentLen = _readUint16LE(data, pos + 32);
        final localHeaderOffset = _readUint32LE(data, pos + 42);

        final fileName = utf8.decode(
            data.sublist(pos + 46, pos + 46 + fileNameLen),
            allowMalformed: true);

        if (fileName == 'xl/styles.xml') {
          stylesLocalOffset = localHeaderOffset;
          stylesCompressedSize = compressedSize;
          stylesUncompressedSize = uncompressedSize;
          stylesCompressionMethod = compressionMethod;
        }

        pos += 46 + fileNameLen + extraLen + commentLen;
      }

      if (stylesLocalOffset == null) return null;

      // Read local file header to find actual data offset
      final localPos = stylesLocalOffset;
      if (data[localPos] != 0x50 || data[localPos + 1] != 0x4B ||
          data[localPos + 2] != 0x03 || data[localPos + 3] != 0x04) { return null; }

      final localFileNameLen = _readUint16LE(data, localPos + 26);
      final localExtraLen = _readUint16LE(data, localPos + 28);
      final dataStart = localPos + 30 + localFileNameLen + localExtraLen;
      final dataEnd = dataStart + stylesCompressedSize;

      // Decompress styles.xml content
      final compressedData = data.sublist(dataStart, dataEnd);
      List<int> xmlBytes;
      if (stylesCompressionMethod == 0) {
        // Stored (no compression)
        xmlBytes = compressedData;
      } else if (stylesCompressionMethod == 8) {
        // Deflate
        xmlBytes = ZLibDecoder().convert(compressedData);
      } else {
        return null; // Unknown compression
      }

      // Patch the XML: remove numFmt elements with id < 164 (built-in range)
      // that should not be redefined, as they cause the mismatch crash.
      var xmlStr = utf8.decode(xmlBytes, allowMalformed: true);
      xmlStr = _sanitizeNumFmts(xmlStr);

      // Re-compress the patched XML
      final newXmlBytes = utf8.encode(xmlStr);
      List<int> newCompressedData;
      int newCompressionMethod;
      if (stylesCompressionMethod == 8) {
        newCompressedData = ZLibEncoder().convert(newXmlBytes);
        newCompressionMethod = 8;
      } else {
        newCompressedData = newXmlBytes;
        newCompressionMethod = 0;
      }

      // Rebuild the ZIP: replace the styles.xml data in-place if sizes match,
      // otherwise rebuild the full archive byte array.
      final newData = _rebuildZipWithPatchedEntry(
        original: data,
        entryCount: entryCount,
        cdOffset: cdOffset,
        cdSize: cdSize,
        eocdOffset: eocdOffset,
        localHeaderOffset: stylesLocalOffset,
        localFileNameLen: localFileNameLen,
        localExtraLen: localExtraLen,
        oldCompressedSize: stylesCompressedSize,
        oldUncompressedSize: stylesUncompressedSize,
        newCompressedData: newCompressedData,
        newUncompressedSize: newXmlBytes.length,
        newCompressionMethod: newCompressionMethod,
      );

      return newData;
    } catch (e) {
      debugPrint('_patchXlsxStyles failed: $e');
      return null;
    }
  }

  /// Removes numFmt XML elements whose numFmtId is in the built-in range (< 164).
  /// Handles both self-closing (<numFmt ... />) and non-self-closing
  /// (<numFmt ...>...</numFmt>) forms produced by WPS Office / LibreOffice.
  static String _sanitizeNumFmts(String xml) {
    // Step 1: Remove self-closing <numFmt ... numFmtId="NNN" ... />
    var result = xml.replaceAllMapped(
      RegExp(r'<numFmt\s[^>]*numFmtId="(\d+)"[^>]*/>', multiLine: true),
      (m) {
        final id = int.tryParse(m.group(1) ?? '') ?? 999;
        return id < 164 ? '' : m.group(0)!;
      },
    );

    // Step 2: Remove non-self-closing <numFmt numFmtId="NNN" ...>...</numFmt>
    result = result.replaceAllMapped(
      RegExp(
          r'<numFmt\s[^>]*numFmtId="(\d+)"[^>]*>.*?</numFmt>',
          multiLine: true,
          dotAll: true),
      (m) {
        final id = int.tryParse(m.group(1) ?? '') ?? 999;
        return id < 164 ? '' : m.group(0)!;
      },
    );

    return result;
  }

  static int _readUint16LE(Uint8List data, int offset) {
    return data[offset] | (data[offset + 1] << 8);
  }

  static int _readUint32LE(Uint8List data, int offset) {
    return data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
  }

  static void _writeUint16LE(Uint8List data, int offset, int value) {
    data[offset] = value & 0xFF;
    data[offset + 1] = (value >> 8) & 0xFF;
  }

  static void _writeUint32LE(Uint8List data, int offset, int value) {
    data[offset] = value & 0xFF;
    data[offset + 1] = (value >> 8) & 0xFF;
    data[offset + 2] = (value >> 16) & 0xFF;
    data[offset + 3] = (value >> 24) & 0xFF;
  }

  /// Rebuilds a ZIP archive with one entry's compressed data replaced.
  static List<int> _rebuildZipWithPatchedEntry({
    required Uint8List original,
    required int entryCount,
    required int cdOffset,
    required int cdSize,
    required int eocdOffset,
    required int localHeaderOffset,
    required int localFileNameLen,
    required int localExtraLen,
    required int oldCompressedSize,
    required int oldUncompressedSize,
    required List<int> newCompressedData,
    required int newUncompressedSize,
    required int newCompressionMethod,
  }) {
    final dataStart =
        localHeaderOffset + 30 + localFileNameLen + localExtraLen;
    final oldDataEnd = dataStart + oldCompressedSize;
    final sizeDelta = newCompressedData.length - oldCompressedSize;

    // Build new byte array
    final newSize = original.length + sizeDelta;
    final out = Uint8List(newSize);

    // Copy everything before compressed data
    out.setRange(0, dataStart, original, 0);

    // Patch local header: compression method, compressed size, uncompressed size
    _writeUint16LE(out, localHeaderOffset + 8, newCompressionMethod);
    _writeUint32LE(out, localHeaderOffset + 18, newCompressedData.length);
    _writeUint32LE(out, localHeaderOffset + 22, newUncompressedSize);

    // Write new compressed data
    out.setRange(dataStart, dataStart + newCompressedData.length,
        newCompressedData);

    // Copy everything after old compressed data up to central directory
    final afterOldData = oldDataEnd;
    final beforeCd = cdOffset;
    if (beforeCd > afterOldData) {
      out.setRange(dataStart + newCompressedData.length,
          dataStart + newCompressedData.length + (beforeCd - afterOldData),
          original, afterOldData);
    }

    // Rewrite central directory, adjusting offsets for entries after the patched one
    final newCdOffset = cdOffset + sizeDelta;
    int readPos = cdOffset;
    int writePos = newCdOffset;

    for (int e = 0; e < entryCount; e++) {
      if (original[readPos] != 0x50 || original[readPos + 1] != 0x4B ||
          original[readPos + 2] != 0x01 || original[readPos + 3] != 0x02) { break; }

      final fnLen = _readUint16LE(original, readPos + 28);
      final extLen = _readUint16LE(original, readPos + 30);
      final cmtLen = _readUint16LE(original, readPos + 32);
      final entrySize = 46 + fnLen + extLen + cmtLen;
      final entryLocalOffset = _readUint32LE(original, readPos + 42);

      out.setRange(writePos, writePos + entrySize, original, readPos);

      // Patch compressed/uncompressed size and compression method for styles entry
      if (entryLocalOffset == localHeaderOffset) {
        _writeUint16LE(out, writePos + 10, newCompressionMethod);
        _writeUint32LE(out, writePos + 20, newCompressedData.length);
        _writeUint32LE(out, writePos + 24, newUncompressedSize);
      }

      // Adjust local header offset if this entry comes after the patched entry
      if (entryLocalOffset > localHeaderOffset) {
        _writeUint32LE(
            out, writePos + 42, entryLocalOffset + sizeDelta);
      }

      readPos += entrySize;
      writePos += entrySize;
    }

    // Write EOCD with updated CD offset
    final newEocdOffset = eocdOffset + sizeDelta;
    out.setRange(newEocdOffset, newEocdOffset + 22, original, eocdOffset);
    _writeUint32LE(out, newEocdOffset + 16, newCdOffset);

    return out;
  }
}

/// Public data class surfaced by the dry-run preview.
/// The screen uses this instead of the private _PriceUpdateResult.
class PriceChangePreview {
  final String excelName;    // Name as it appears in the Excel file
  final String? dbName;      // Matched name in the database
  final double? oldPrice;    // Current price in DB
  final double? newPrice;    // Price from Excel
  final double? newGst;
  final bool isMatched;      // false → not found in DB

  final bool isNewInsert;

  const PriceChangePreview({
    required this.excelName,
    this.dbName,
    this.oldPrice,
    this.newPrice,
    this.newGst,
    required this.isMatched,
    this.isNewInsert = false,
  });

  /// e.g. "3200 → 3450"
  String get priceDelta {
    final o = oldPrice;
    final n = newPrice;
    if (o == null || n == null) return n?.toStringAsFixed(0) ?? '-';
    return '${o.toStringAsFixed(0)} → ${n.toStringAsFixed(0)}';
  }

  /// 1 = price went up, -1 = went down, 0 = unchanged
  int get priceDirection {
    final o = oldPrice ?? 0;
    final n = newPrice ?? 0;
    if (n > o) return 1;
    if (n < o) return -1;
    return 0;
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

enum _UpdateStatus { pending, updated, notFound, zeroPriceSkipped, error }

/// Holds one proposed or committed price change for a single product.
/// Mutable so it can transition: pending → updated | error after commit.
class _PriceUpdateResult {
  final String excelName;
  final String? dbName;
  final String? dbProductId;
  final double? oldPrice;   // current price in DB (null if not matched)
  final double? newPrice;   // price from Excel
  final double? newGst;
  final String? newUnit;
  final String? newSku;
  _UpdateStatus status;
  String? errorMsg;
  final bool isNewInsert;

  _PriceUpdateResult({
    required this.excelName,
    this.dbName,
    this.dbProductId,
    this.oldPrice,
    this.newPrice,
    this.newGst,
    this.newUnit,
    this.newSku,
    required this.status,
    this.isNewInsert = false,
  });

  void markCommitted() => status = _UpdateStatus.updated;
  void markError(String msg) {
    status = _UpdateStatus.error;
    errorMsg = msg;
  }

  /// Human-readable price delta string, e.g. "3200 → 3450"
  String get priceDelta {
    final o = oldPrice;
    final n = newPrice;
    if (o == null || n == null) return n?.toStringAsFixed(0) ?? '-';
    return '${o.toStringAsFixed(0)} → ${n.toStringAsFixed(0)}';
  }

  /// Whether the new price is higher, lower, or unchanged
  int get priceDirection {
    final o = oldPrice ?? 0;
    final n = newPrice ?? 0;
    if (n > o) return 1;   // up
    if (n < o) return -1;  // down
    return 0;              // same
  }
}
