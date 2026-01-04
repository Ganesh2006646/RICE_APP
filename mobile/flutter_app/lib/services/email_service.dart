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
      // Check if file exists
      final file = XFile(filePath,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

      // Verify file can be accessed
      final fileLength = await file.length();
      if (fileLength == 0) {
        debugPrint('Error: File is empty');
        return false;
      }

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

      final result = await Share.shareXFiles(
        [file],
        subject: subject,
        text: body,
      );

      // Check if sharing was successful
      if (result.status == ShareResultStatus.success) {
        debugPrint('File shared successfully');
        return true;
      } else if (result.status == ShareResultStatus.dismissed) {
        debugPrint('Share dismissed by user');
        return false;
      } else {
        debugPrint('Share failed with status: ${result.status}');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('Error sharing file: $e');
      debugPrint('Stack trace: $stackTrace');
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
    String currencySymbol = '₹',
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
Total Amount: $currencySymbol${totalAmount.toStringAsFixed(2)}
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
