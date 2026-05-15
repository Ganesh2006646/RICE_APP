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
      final ByteData data = await rootBundle.load('assets/images/sri_balaji_logo.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      // Ignore if logo not found
    }

    final dateStr = DateFormat('dd-MMM-yyyy').format(order.loadingDate);
    final nf = NumberFormat('#,##0', 'en_US');
    
    double totalQtl = 0;
    double totalAmt = 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 60,
                      height: 60,
                      child: pw.Image(logoImage),
                    ),
                  if (logoImage != null) pw.SizedBox(width: 20),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(millName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 4),
                      pw.Text('Jaggampeta, East Godavari, Andhra Pradesh', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 10),
              
              // Customer & Order Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Bill To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.grey700)),
                      pw.SizedBox(height: 5),
                      pw.Text(customer.shopName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      if (customer.place != null && customer.place!.isNotEmpty) 
                        pw.Text(customer.place!, style: const pw.TextStyle(fontSize: 12)),
                      if (customer.phone != null && customer.phone!.isNotEmpty) 
                        pw.Text('Ph: ${customer.phone}', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800, letterSpacing: 1.2)),
                      pw.SizedBox(height: 10),
                      pw.Text('Order #: ${order.notes ?? "N/A"}', style: const pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(height: 2),
                      pw.Text('Date: $dateStr', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 30),
              
              // Table Header
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue200),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text('Item Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))),
                    pw.Expanded(flex: 3, child: pw.Text('Bags Details', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))),
                    pw.Expanded(flex: 1, child: pw.Text('QTL', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))),
                    pw.Expanded(flex: 2, child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))),
                    pw.Expanded(flex: 3, child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              
              // Table Rows
              ...items.where((i) => i.bags26 > 0 || i.bags10 > 0 || i.bags5 > 0).map((item) {
                final product = products.firstWhere((p) => p.id == item.productId,
                    orElse: () => Product(id: '', name: 'Rice', defaultPrice: 0, gstRateDefault: 0, unit: 'qtl', createdAt: DateTime.now(), updatedAt: DateTime.now()));
                
                List<String> bagParts = [];
                if (item.bags26 > 0) bagParts.add('${item.bags26}x26kg');
                if (item.bags10 > 0) bagParts.add('${item.bags10}x10kg');
                if (item.bags5 > 0) bagParts.add('${item.bags5}x5kg');

                totalQtl += item.qtyQtl;
                totalAmt += item.netAmount;

                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text(product.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 3, child: pw.Text(bagParts.join(' '), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 1, child: pw.Text(item.qtyQtl.toStringAsFixed(2), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 2, child: pw.Text('$currencySymbol${nf.format(item.ratePerQtl)}', textAlign: pw.TextAlign.right)),
                      pw.Expanded(flex: 3, child: pw.Text('$currencySymbol${nf.format(item.netAmount)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                );
              }).toList(),
              
              pw.SizedBox(height: 20),
              
              // Totals
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text('Total Quantity:', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700))),
                    pw.Expanded(flex: 2, child: pw.Text('${totalQtl.toStringAsFixed(2)} QTL', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 3, child: pw.Text('Total Amount:', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700))),
                    pw.Expanded(flex: 3, child: pw.Text('$currencySymbol${nf.format(totalAmt)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue900))),
                  ],
                ),
              ),
              
              pw.Spacer(),
              
              // Footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Caution: Auto generated document.', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Thanks & Regards', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
                      pw.SizedBox(height: 4),
                      pw.Text('by $agentName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final safeName = customer.shopName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final safeOrderNo = (order.notes ?? safeName).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final file = File('${dir.path}/Invoice_$safeOrderNo.pdf');
    await file.writeAsBytes(await pdf.save());
    
    // Share the PDF
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Invoice for ${customer.shopName} from $millName',
    );
  }
}
