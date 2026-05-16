import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../db/database.dart';

class PdfService {
  static Future<void> generateAndShareInvoice({
    required Customer customer,
    required Order order,
    required List<OrderItem> items,
    required List<Product> products,
    String currencySymbol = 'Rs.',
    String agentName = 'Narendra',
    String millName = 'Sri Balaji Boiled and Raw Rice Mill',
  }) async {
    final pdf = pw.Document();

    // Load logo
    pw.MemoryImage? logoImage;
    try {
      final ByteData data =
          await rootBundle.load('assets/images/sri_balaji_logo.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      // Logo not found — continue without it
    }

    final dateStr = DateFormat('dd-MMM-yyyy').format(order.loadingDate);
    final nf = NumberFormat('#,##0', 'en_US');

    double totalQtl = 0;
    double totalAmt = 0;

    // Pre-compute totals (must be outside the pw.Page builder)
    for (final item in items.where(
        (i) => i.bags26 > 0 || i.bags10 > 0 || i.bags5 > 0)) {
      totalQtl += item.qtyQtl;
      totalAmt += item.netAmount;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null) ...[
                    pw.Container(
                      width: 52,
                      height: 52,
                      child: pw.Image(logoImage),
                    ),
                    pw.SizedBox(width: 12),
                  ],
                  // Expanded text column to prevent header overflow
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          millName,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Jaggampeta, East Godavari, Andhra Pradesh',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                  // INVOICE badge on the right
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColors.green200),
                    ),
                    child: pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 10),

              // ── Customer & Order Info ────────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Bill To
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Bill To:',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                                color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(customer.shopName,
                            style: pw.TextStyle(
                                fontSize: 15,
                                fontWeight: pw.FontWeight.bold)),
                        if (customer.place?.isNotEmpty == true)
                          pw.Text(customer.place!,
                              style: const pw.TextStyle(fontSize: 11)),
                        if (customer.phone?.isNotEmpty == true)
                          pw.Text('Ph: ${customer.phone}',
                              style: const pw.TextStyle(fontSize: 11)),
                        if (customer.tinGst?.isNotEmpty == true)
                          pw.Text('GST: ${customer.tinGst}',
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  // Order details
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Order #: ${order.notes ?? "N/A"}',
                            style: const pw.TextStyle(fontSize: 11)),
                        pw.SizedBox(height: 3),
                        pw.Text('Date: $dateStr',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // ── Table Header ─────────────────────────────────────────
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green200),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                        flex: 4,
                        child: pw.Text('Item',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                                color: PdfColors.green900))),
                    pw.Expanded(
                        flex: 3,
                        child: pw.Text('Bags',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                                color: PdfColors.green900))),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text('QTL',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                                color: PdfColors.green900))),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text('Rate',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                                color: PdfColors.green900))),
                    pw.Expanded(
                        flex: 3,
                        child: pw.Text('Amount',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                                color: PdfColors.green900))),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),

              // ── Table Rows ───────────────────────────────────────────
              ...items
                  .where((i) => i.bags26 > 0 || i.bags10 > 0 || i.bags5 > 0)
                  .map((item) {
                final product = products.firstWhere(
                  (p) => p.id == item.productId,
                  orElse: () => Product(
                    id: '',
                    name: 'Rice',
                    defaultPrice: 0,
                    gstRateDefault: 0,
                    unit: 'qtl',
                    isGalaxy: false,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                );

                final bagParts = <String>[
                  if (item.bags26 > 0) '${item.bags26}×26kg',
                  if (item.bags10 > 0) '${item.bags10}×10kg',
                  if (item.bags5 > 0) '${item.bags5}×5kg',
                ];

                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 5, horizontal: 10),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(
                            color: PdfColors.grey300, width: 0.5)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                          flex: 4,
                          child: pw.Text(product.name,
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10))),
                      pw.Expanded(
                          flex: 3,
                          child: pw.Text(bagParts.join(' '),
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 9))),
                      pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                              item.qtyQtl.toStringAsFixed(2),
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(
                          flex: 2,
                          child: pw.Text(nf.format(item.ratePerQtl),
                              textAlign: pw.TextAlign.right,
                              style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(
                          flex: 3,
                          child: pw.Text(nf.format(item.netAmount),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10))),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 16),

              // ── Totals ───────────────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.green200),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text('Total Quantity:',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                              color: PdfColors.grey700)),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text('${totalQtl.toStringAsFixed(2)} QTL',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.SizedBox(width: 24),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('Grand Total:',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                              color: PdfColors.grey700)),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(nf.format(totalAmt),
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                            color: PdfColors.green900)),
                  ],
                ),
              ),

              pw.Spacer(),

              // ── Footer ───────────────────────────────────────────────
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Auto generated document. Data may be subject to rounding.',
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey500,
                        fontStyle: pw.FontStyle.italic),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Thanks & Regards',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text('by $agentName',
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green900)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final safeName =
        customer.shopName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final safeOrderNo = (order.notes ?? safeName)
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName =
        'Invoice_${safeOrderNo}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text:
          'Invoice for ${customer.shopName} — Order #${order.notes ?? "N/A"} from $millName',
    );
  }
}
