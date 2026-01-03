import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings_service.dart';

/// Service for sending order emails via Gmail
/// Uses share_plus for file attachment support
class EmailService {
  /// Share order Excel file via system share sheet
  /// This allows user to send via Gmail, WhatsApp, etc.
  static Future<bool> shareOrderExcel({
    required String filePath,
    required String customerName,
    required String orderNumber,
    String? recipientEmail,
  }) async {
    try {
      final file = XFile(filePath);
      final millEmail = recipientEmail ?? await SettingsService.getMillEmail();

      final subject = 'Order $orderNumber - $customerName';
      final body = '''
🌾 *Sri Balaji Rice Mill - New Load Order* 🌾
--------------------------------------------
Order No: $orderNumber
Party: $customerName

Dear Team,

Please find the attached Lorry Load Sheet for the above order. 
Kindly process the shipment and confirm the loading status.

Regards,
Kankatala Narayana Murthy
Sri Balaji Rice Mill
''';

      await Share.shareXFiles(
        [file],
        subject: subject,
        text: body,
      );

      return true;
    } catch (e) {
      debugPrint('Error sharing file: $e');
      return false;
    }
  }

  /// Open Gmail directly with pre-filled content (without attachment)
  /// User can manually attach the file if needed
  static Future<bool> openGmailWithContent({
    required String recipient,
    required String subject,
    required String body,
  }) async {
    final gmailUrl = Uri(
      scheme: 'mailto',
      path: recipient,
      query: _encodeQueryParameters({
        'subject': subject,
        'body': body,
      }),
    );

    try {
      if (await canLaunchUrl(gmailUrl)) {
        await launchUrl(gmailUrl);
        return true;
      }
    } catch (e) {
      debugPrint('Error opening email: $e');
    }
    return false;
  }

  /// Generate professional email body for order
  static String generateOrderEmailBody({
    required String orderNumber,
    required String customerName,
    required String customerPlace,
    required double totalQtl,
    required double totalAmount,
    required int itemCount,
  }) {
    return '''
Dear Sir/Madam,

Please find attached the order sheet with the following details:

----------------------------------------
ORDER DETAILS
----------------------------------------
Order Number: $orderNumber
Customer: $customerName
Place: $customerPlace
Items: $itemCount rice varieties
Total Quantity: ${totalQtl.toStringAsFixed(2)} QTL
Total Amount: ₹${totalAmount.toStringAsFixed(2)}
----------------------------------------

Kindly arrange for loading as per the attached order sheet.

Thank you for your continued partnership.

Best regards,
Rice Agent

---
This order was generated using RiceAgent App.
''';
  }

  /// Encode query parameters for URL
  static String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  /// Check if email app is available
  static Future<bool> isEmailAvailable() async {
    final Uri emailUri = Uri(scheme: 'mailto');
    return await canLaunchUrl(emailUri);
  }
}
