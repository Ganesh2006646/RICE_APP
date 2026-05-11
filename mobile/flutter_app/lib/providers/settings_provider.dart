import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Generates collision-free unique IDs using UUID v4
String generateId() => const Uuid().v4();

/// Type-safe language enum to prevent string-matching bugs
enum AppLanguage {
  english('English', 'en'),
  telugu('Telugu', 'te'),
  hindi('Hindi', 'hi'),
  tamil('Tamil', 'ta');

  final String displayName;
  final String localeCode;
  const AppLanguage(this.displayName, this.localeCode);

  /// Parse from stored string, defaulting to English
  static AppLanguage fromString(String? value) {
    if (value == null) return AppLanguage.english;
    return AppLanguage.values.firstWhere(
      (e) => e.displayName.toLowerCase() == value.toLowerCase(),
      orElse: () => AppLanguage.english,
    );
  }
}

/// App Settings State
class AppSettings {
  final AppLanguage language;
  final String fontSize;
  final int defaultDueDays;
  final String millEmail;
  final String millContactPhone;
  final String invoicePrefix;
  final String currencySymbol;
  final String excelSavePath;
  final bool autoBackupEnabled;
  final String agentName;   // Agent name for email/WhatsApp signatures
  final String millName;    // Mill name for headers

  // Configurable Business Logic (previously hardcoded)
  final double packing10Price; // Packing surcharge per 10kg bag (₹/Qtl added to base rate)
  final double packing5Price;  // Packing surcharge per 5kg bag  (₹/Qtl added to base rate)
  final double amcPercent;     // AMC percentage (e.g. 1.0 = 1%)
  final double gstPercent;     // GST percentage (e.g. 5.0 = 5%)

  /// Alias: surcharge applied per quintal for 10 KG packing (same storage as packing10Price)
  double get surcharge10kgPerQtl => packing10Price;
  /// Alias: surcharge applied per quintal for 5 KG packing (same storage as packing5Price)
  double get surcharge5kgPerQtl => packing5Price;

  const AppSettings({
    this.language = AppLanguage.english,
    this.fontSize = 'Medium',
    this.defaultDueDays = 7,
    this.millEmail = 'sbbrrm@gmail.com',
    this.millContactPhone = '9885185666',
    this.invoicePrefix = 'SBRM-2024-',
    this.currencySymbol = '₹',
    this.excelSavePath = '',
    this.autoBackupEnabled = true,
    this.agentName = 'Narendra',
    this.millName = 'Sri Balaji Boiled and Raw Rice Mill',
    this.packing10Price = 200.0,
    this.packing5Price = 250.0,
    this.amcPercent = 1.0,
    this.gstPercent = 5.0,
  });

  AppSettings copyWith({
    AppLanguage? language,
    String? fontSize,
    int? defaultDueDays,
    String? millEmail,
    String? millContactPhone,
    String? invoicePrefix,
    String? currencySymbol,
    String? excelSavePath,
    bool? autoBackupEnabled,
    double? packing10Price,
    double? packing5Price,
    double? amcPercent,
    double? gstPercent,
    String? agentName,
    String? millName,
  }) {
    return AppSettings(
      language: language ?? this.language,
      fontSize: fontSize ?? this.fontSize,
      defaultDueDays: defaultDueDays ?? this.defaultDueDays,
      millEmail: millEmail ?? this.millEmail,
      millContactPhone: millContactPhone ?? this.millContactPhone,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      excelSavePath: excelSavePath ?? this.excelSavePath,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      agentName: agentName ?? this.agentName,
      millName: millName ?? this.millName,
      packing10Price: packing10Price ?? this.packing10Price,
      packing5Price: packing5Price ?? this.packing5Price,
      amcPercent: amcPercent ?? this.amcPercent,
      gstPercent: gstPercent ?? this.gstPercent,
    );
  }

  double get fontScale {
    switch (fontSize) {
      case 'Small':
        return 0.85;
      case 'Large':
        return 1.2;
      default:
        return 1.0;
    }
  }

  bool get isDarkMode => false; // Hardcoded to light mode
  bool get isAdvancedMode => true; // Keep as true or remove if unused elsewhere
}

/// Settings Notifier to manage app settings state
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      language: AppLanguage.fromString(prefs.getString('language')),
      fontSize: prefs.getString('fontSize') ?? 'Medium',
      defaultDueDays: prefs.getInt('defaultDueDays') ?? 7,
      millEmail: prefs.getString('mill_email') ?? 'sbbrrm@gmail.com',
      millContactPhone: prefs.getString('mill_contact') ?? '9885185666',
      invoicePrefix: prefs.getString('invoice_prefix') ?? 'SBRM-2024-',
      currencySymbol: prefs.getString('currency_symbol') ?? '₹',
      excelSavePath: prefs.getString('excel_save_path') ?? '',
      autoBackupEnabled: prefs.getBool('auto_backup_enabled') ?? true,
      agentName: prefs.getString('agent_name') ?? 'Narendra',
      millName: prefs.getString('mill_name') ?? 'Sri Balaji Boiled and Raw Rice Mill',
      packing10Price: prefs.getDouble('packing_10_price') ?? 200.0,
      packing5Price: prefs.getDouble('packing_5_price') ?? 250.0,
      amcPercent: prefs.getDouble('amc_percent') ?? 1.0,
      gstPercent: prefs.getDouble('gst_percent') ?? 5.0,
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language.displayName);
    state = state.copyWith(language: language);
  }

  Future<void> setFontSize(String fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontSize', fontSize);
    state = state.copyWith(fontSize: fontSize);
  }

  Future<void> setDefaultDueDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('defaultDueDays', days);
    state = state.copyWith(defaultDueDays: days);
  }

  Future<void> setMillEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mill_email', email);
    state = state.copyWith(millEmail: email);
  }

  Future<void> setMillContactPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mill_contact', phone);
    state = state.copyWith(millContactPhone: phone);
  }

  Future<void> setInvoicePrefix(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('invoice_prefix', prefix);
    state = state.copyWith(invoicePrefix: prefix);
  }

  Future<void> setCurrencySymbol(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency_symbol', symbol);
    state = state.copyWith(currencySymbol: symbol);
  }

  Future<void> setExcelSavePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('excel_save_path', path);
    state = state.copyWith(excelSavePath: path);
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', enabled);
    state = state.copyWith(autoBackupEnabled: enabled);
  }

  Future<void> setAgentName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('agent_name', name);
    state = state.copyWith(agentName: name);
  }

  Future<void> setMillName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mill_name', name);
    state = state.copyWith(millName: name);
  }

  Future<void> setPacking10Price(double price) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('packing_10_price', price);
    state = state.copyWith(packing10Price: price);
  }

  Future<void> setPacking5Price(double price) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('packing_5_price', price);
    state = state.copyWith(packing5Price: price);
  }

  Future<void> setAmcPercent(double percent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('amc_percent', percent);
    state = state.copyWith(amcPercent: percent);
  }

  Future<void> setGstPercent(double percent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('gst_percent', percent);
    state = state.copyWith(gstPercent: percent);
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const AppSettings();
  }
}

/// Global settings provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);
