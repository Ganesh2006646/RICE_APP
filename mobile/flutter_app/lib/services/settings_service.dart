import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app settings using SharedPreferences
/// Provides centralized access to user preferences
class SettingsService {
  static const String _keyMillEmail = 'mill_email';
  static const String _keyInvoicePrefix = 'invoice_prefix';
  static const String _keyAgentName = 'agent_name';

  // Default values - Official Sri Balaji Rice Mill
  static const String defaultMillEmail = 'sbbrrm@gmail.com';
  static const String defaultInvoicePrefix = 'SBRM-2024-';
  static const String defaultAgentName = 'Narendra';

  /// Get the default mill email for sending orders
  static Future<String> getMillEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMillEmail) ?? defaultMillEmail;
  }

  /// Set the default mill email
  static Future<void> setMillEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMillEmail, email);
  }

  /// Get the invoice prefix (e.g., RA-2024-)
  static Future<String> getInvoicePrefix() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyInvoicePrefix) ?? defaultInvoicePrefix;
  }

  /// Set the invoice prefix
  static Future<void> setInvoicePrefix(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyInvoicePrefix, prefix);
  }

  /// Get the agent name
  static Future<String> getAgentName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAgentName) ?? defaultAgentName;
  }

  /// Set the agent name
  static Future<void> setAgentName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAgentName, name);
  }

  /// Generate the next order number based on prefix
  static Future<String> generateOrderNumber(int orderCount) async {
    final prefix = await getInvoicePrefix();
    final orderNum = (orderCount + 1).toString().padLeft(4, '0');
    return '$prefix$orderNum';
  }

  /// Reset all settings to defaults
  static Future<void> resetAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMillEmail);
    await prefs.remove(_keyInvoicePrefix);
    await prefs.remove(_keyAgentName);
  }

  /// Get all settings as a map (for display purposes)
  static Future<Map<String, String>> getAllSettings() async {
    return {
      'millEmail': await getMillEmail(),
      'invoicePrefix': await getInvoicePrefix(),
      'agentName': await getAgentName(),
    };
  }
}
