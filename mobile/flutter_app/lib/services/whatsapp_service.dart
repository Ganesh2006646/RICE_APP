import 'package:url_launcher/url_launcher.dart';
import '../db/database.dart';

/// Service for sending order details via WhatsApp
class WhatsAppService {
  /// Open WhatsApp with a pre-formatted message for a specific customer
  static Future<void> sendOrderMessage({
    required Customer customer,
    required Order order,
    required List<OrderItem> items,
    required List<Product> products,
    String currencySymbol = '₹',
  }) async {
    final phone = customer.phone;
    if (phone == null || phone.isEmpty) {
      throw 'Customer phone number is missing';
    }

    // Format phone number (ensure no spaces and has country code)
    // For India, if 10 digits, add +91
    String formattedPhone = phone.replaceAll(RegExp(r'\s+'), '');
    if (formattedPhone.length == 10) {
      formattedPhone = '91$formattedPhone';
    }

    // Build Message
    final StringBuffer message = StringBuffer();
    message.writeln('🌾 *Sri Balaji Rice Mill - Order Details* 🌾');
    message.writeln('------------------------------------------');
    message.writeln('*Order No:* ${order.notes ?? 'N/A'}');
    message.writeln('*Party:* ${customer.shopName}');
    message.writeln('*Place:* ${customer.place ?? 'N/A'}');
    message.writeln('------------------------------------------');
    message.writeln('*Rice Varieties:*');

    for (var item in items) {
      final product = products.firstWhere((p) => p.id == item.productId,
          orElse: () => Product(
              id: '',
              name: 'Rice',
              defaultPrice: 0,
              gstRateDefault: 0,
              unit: 'qtl',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now()));

      message.write('• ${product.name}: ');

      List<String> bags = [];
      if (item.bags26 > 0) bags.add('${item.bags26} (26kg)');
      if (item.bags10 > 0) bags.add('${item.bags10} (10kg)');
      if (item.bags5 > 0) bags.add('${item.bags5} (5kg)');

      message.writeln(bags.join(', '));
      message.writeln(
          '  Qty: ${item.qtyQtl.toStringAsFixed(2)} QTL @ $currencySymbol${item.ratePerQtl.toStringAsFixed(0)}');
    }

    message.writeln('------------------------------------------');
    final double totalAmount =
        items.fold<double>(0, (sum, i) => sum + i.netAmount);
    final double totalQtl = items.fold<double>(0, (sum, i) => sum + i.qtyQtl);
    final int itemCount = items.length;

    message.writeln('Order Number: ${order.notes ?? 'N/A'}');
    message.writeln('Customer: ${customer.shopName}');
    message.writeln('Place: ${customer.place ?? 'N/A'}');
    message.writeln('Items: $itemCount rice varieties');
    message.writeln('Total Quantity: ${totalQtl.toStringAsFixed(2)} QTL');
    message.writeln(
        'Total Amount: $currencySymbol${totalAmount.toStringAsFixed(2)}');
    message.writeln('------------------------------------------');
    message.writeln('Regards,');
    message.writeln('Kankatala Narayana Murthy');

    final encodedMsg = Uri.encodeComponent(message.toString());
    final url = 'whatsapp://send?phone=$formattedPhone&text=$encodedMsg';

    // Fallback for web/desktop or if whatsapp:// fails
    final fallbackUrl = 'https://wa.me/$formattedPhone?text=$encodedMsg';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        await launchUrl(Uri.parse(fallbackUrl),
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      throw 'Could not launch WhatsApp: $e';
    }
  }

  /// Open WhatsApp with a summary of the ENTIRE lorry load (multi-customer)
  static Future<void> sendLorrySummaryMessage({
    required List<Customer> customers,
    required Order order,
    required List<OrderItem> allItems,
    required List<Product> allProducts,
    required String millContactPhone,
    String currencySymbol = '₹',
  }) async {
    // Format phone number
    String formattedPhone = millContactPhone.replaceAll(RegExp(r'\s+'), '');
    if (formattedPhone.length == 10) formattedPhone = '91$formattedPhone';

    final StringBuffer message = StringBuffer();
    message.writeln('🚚 *Sri Balaji Rice Mill - FULL LORRY SUMMARY* 🚚');
    message.writeln('------------------------------------------');
    message.writeln('*Order No:* ${order.notes ?? 'N/A'}');
    message.writeln('*Date:* ${order.loadingDate.toString().split(' ')[0]}');
    message.writeln('------------------------------------------');

    double grandTotalQtl = 0;
    double grandTotalAmount = 0;

    for (var customer in customers) {
      final customerItems =
          allItems.where((i) => i.customerId == customer.id).toList();
      if (customerItems.isEmpty) continue;

      message.writeln('\n👤 *${customer.shopName}* (${customer.place})');
      for (var item in customerItems) {
        final product = allProducts.firstWhere((p) => p.id == item.productId,
            orElse: () => Product(
                id: '',
                name: 'Rice',
                defaultPrice: 0,
                gstRateDefault: 0,
                unit: 'qtl',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now()));
        message.writeln(
            '• ${product.name}: ${item.qtyQtl.toStringAsFixed(2)} QTL');
        grandTotalQtl += item.qtyQtl;
        grandTotalAmount += item.netAmount;
      }
    }

    message.writeln('\n------------------------------------------');
    message.writeln('*GRAND TOTAL QTL: ${grandTotalQtl.toStringAsFixed(2)}*');
    message.writeln(
        '*GRAND TOTAL VALUE: $currencySymbol${grandTotalAmount.toStringAsFixed(0)}*');
    message.writeln('------------------------------------------');
    message.writeln('Regards, RiceAgent App');

    final encodedMsg = Uri.encodeComponent(message.toString());
    final url = 'whatsapp://send?phone=$formattedPhone&text=$encodedMsg';
    final fallbackUrl = 'https://wa.me/$formattedPhone?text=$encodedMsg';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        await launchUrl(Uri.parse(fallbackUrl),
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      throw 'Could not launch WhatsApp Summary: $e';
    }
  }
}
