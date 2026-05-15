import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db/database.dart';

/// Service for sending order details via WhatsApp
/// Compact message format optimized for mobile readability
class WhatsAppService {
  /// Open WhatsApp with a compact message for a specific customer
  static Future<void> sendOrderMessage({
    required Customer customer,
    required Order order,
    required List<OrderItem> items,
    required List<Product> products,
    String currencySymbol = '₹',
    String agentName = 'Narendra',
    String millName = 'Sri Balaji Boiled and Raw Rice Mill',
  }) async {
    final phone = customer.phone;
    if (phone == null || phone.isEmpty) {
      debugPrint('[WhatsApp] Customer phone number is missing');
      return;
    }

    // Format phone number (ensure only digits and country code)
    String formattedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (formattedPhone.length == 10) formattedPhone = '91$formattedPhone';

    final nf = NumberFormat('#,##0', 'en_US');
    final dateStr = DateFormat('dd-MMM').format(order.loadingDate);

    // Build compact message
    final StringBuffer msg = StringBuffer();
    msg.writeln('🌾 *$millName*');
    msg.writeln('Order #${order.notes ?? 'N/A'} • $dateStr');
    msg.writeln('━━━━━━━━━━━━━━━━━');
    msg.writeln('*${customer.shopName}* ${customer.place != null ? '(${customer.place})' : ''}');
    msg.writeln('');

    double totalQtl = 0;
    double totalAmt = 0;

    for (var item in items) {
      if (item.bags26 == 0 && item.bags10 == 0 && item.bags5 == 0) continue;

      final product = products.firstWhere((p) => p.id == item.productId,
          orElse: () => Product(
              id: '', name: 'Rice', defaultPrice: 0, gstRateDefault: 0,
              unit: 'qtl', isGalaxy: false, createdAt: DateTime.now(), updatedAt: DateTime.now()));

      // Compact bag summary: "HMT GREEN GALAXY: 10×26kg 5×10kg"
      List<String> bagParts = [];
      if (item.bags26 > 0) bagParts.add('${item.bags26}×26kg');
      if (item.bags10 > 0) bagParts.add('${item.bags10}×10kg');
      if (item.bags5 > 0) bagParts.add('${item.bags5}×5kg');

      msg.writeln('▸ ${product.name}');
      msg.writeln('  ${bagParts.join(' ')} = ${item.qtyQtl.toStringAsFixed(1)}Q @$currencySymbol${nf.format(item.ratePerQtl)}');

      totalQtl += item.qtyQtl;
      totalAmt += item.netAmount;
    }

    msg.writeln('');
    msg.writeln('━━━━━━━━━━━━━━━━━');
    msg.writeln('*Total: ${totalQtl.toStringAsFixed(1)} QTL • $currencySymbol${nf.format(totalAmt)}*');
    msg.writeln('');
    msg.writeln('— $agentName');

    _launchWhatsApp(formattedPhone, msg.toString());
  }

  /// Open WhatsApp with a compact summary of the ENTIRE lorry load (multi-customer)
  static Future<void> sendLorrySummaryMessage({
    required List<Customer> customers,
    required Order order,
    required List<OrderItem> allItems,
    required List<Product> allProducts,
    required String millContactPhone,
    String currencySymbol = '₹',
    String agentName = 'Narendra',
    String millName = 'Sri Balaji Boiled and Raw Rice Mill',
  }) async {
    // Format phone number
    String formattedPhone = millContactPhone.replaceAll(RegExp(r'\D'), '');
    if (formattedPhone.length == 10) formattedPhone = '91$formattedPhone';

    final nf = NumberFormat('#,##0', 'en_US');
    final dateStr = DateFormat('dd-MMM').format(order.loadingDate);

    final StringBuffer msg = StringBuffer();
    msg.writeln('🚚 *LORRY ORDER #${order.notes ?? 'N/A'}*');
    msg.writeln('$millName • $dateStr');
    msg.writeln('━━━━━━━━━━━━━━━━━');

    double grandQtl = 0;
    double grandAmt = 0;
    int partyNo = 0;

    for (var customer in customers) {
      final customerItems =
          allItems.where((i) => i.customerId == customer.id).toList();
      if (customerItems.isEmpty) continue;

      partyNo++;
      double custQtl = 0;

      msg.writeln('');
      msg.writeln('*$partyNo. ${customer.shopName}* ${customer.place != null ? '· ${customer.place}' : ''}');

      for (var item in customerItems) {
        if (item.bags26 == 0 && item.bags10 == 0 && item.bags5 == 0) continue;

        final product = allProducts.firstWhere((p) => p.id == item.productId,
            orElse: () => Product(
                id: '', name: 'Rice', defaultPrice: 0, gstRateDefault: 0,
                unit: 'qtl', isGalaxy: false, createdAt: DateTime.now(), updatedAt: DateTime.now()));

        // Super compact: "HMT GREEN: 10×26kg = 2.6Q"
        List<String> bags = [];
        if (item.bags26 > 0) bags.add('${item.bags26}×26');
        if (item.bags10 > 0) bags.add('${item.bags10}×10');
        if (item.bags5 > 0) bags.add('${item.bags5}×5');

        msg.writeln('  ${product.name}: ${bags.join(' ')} = ${item.qtyQtl.toStringAsFixed(1)}Q');
        custQtl += item.qtyQtl;
        grandAmt += item.netAmount;
      }
      grandQtl += custQtl;
    }

    msg.writeln('');
    msg.writeln('━━━━━━━━━━━━━━━━━');
    msg.writeln('*$partyNo Parties • ${grandQtl.toStringAsFixed(1)} QTL*');
    msg.writeln('*Total: $currencySymbol${nf.format(grandAmt)}*');
    msg.writeln('');
    msg.writeln('— $agentName');

    _launchWhatsApp(formattedPhone, msg.toString());
  }

  /// Internal helper to launch WhatsApp with message
  static Future<void> _launchWhatsApp(String phone, String message) async {
    final encodedMsg = Uri.encodeComponent(message);
    final url = 'whatsapp://send?phone=$phone&text=$encodedMsg';
    final fallbackUrl = 'https://wa.me/$phone?text=$encodedMsg';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        await launchUrl(Uri.parse(fallbackUrl),
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[WhatsApp] Could not launch WhatsApp: $e');
    }
  }
}
