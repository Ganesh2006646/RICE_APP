import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Settings State
class AppSettings {
  final String language;
  final String fontSize;
  final String appMode;
  final String theme;
  final int defaultDueDays;
  final String millEmail;
  final String millContactPhone;
  final String invoicePrefix;
  final String currencySymbol;
  final String excelSavePath;
  final bool autoBackupEnabled;

  const AppSettings({
    this.language = 'English',
    this.fontSize = 'Medium',
    this.appMode = 'Simple Mode',
    this.theme = 'Light',
    this.defaultDueDays = 7,
    this.millEmail = 'sbbrrm@gmail.com',
    this.millContactPhone = '9885185666',
    this.invoicePrefix = 'SBRM-2024-',
    this.currencySymbol = '₹',
    this.excelSavePath = '',
    this.autoBackupEnabled = true,
  });

  AppSettings copyWith({
    String? language,
    String? fontSize,
    String? appMode,
    String? theme,
    int? defaultDueDays,
    String? millEmail,
    String? millContactPhone,
    String? invoicePrefix,
    String? currencySymbol,
    String? excelSavePath,
    bool? autoBackupEnabled,
  }) {
    return AppSettings(
      language: language ?? this.language,
      fontSize: fontSize ?? this.fontSize,
      appMode: appMode ?? this.appMode,
      theme: theme ?? this.theme,
      defaultDueDays: defaultDueDays ?? this.defaultDueDays,
      millEmail: millEmail ?? this.millEmail,
      millContactPhone: millContactPhone ?? this.millContactPhone,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      excelSavePath: excelSavePath ?? this.excelSavePath,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
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

  bool get isDarkMode => theme == 'Dark';
  bool get isAdvancedMode => appMode == 'Advanced Mode';
}

/// Settings Notifier to manage app settings state
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      language: prefs.getString('language') ?? 'English',
      fontSize: prefs.getString('fontSize') ?? 'Medium',
      appMode: prefs.getString('appMode') ?? 'Simple Mode',
      theme: prefs.getString('theme') ?? 'Light',
      defaultDueDays: prefs.getInt('defaultDueDays') ?? 7,
      millEmail: prefs.getString('mill_email') ?? 'sbbrrm@gmail.com',
      millContactPhone: prefs.getString('mill_contact') ?? '9885185666',
      invoicePrefix: prefs.getString('invoice_prefix') ?? 'SBRM-2024-',
      currencySymbol: prefs.getString('currency_symbol') ?? '₹',
      excelSavePath: prefs.getString('excel_save_path') ?? '',
      autoBackupEnabled: prefs.getBool('auto_backup_enabled') ?? true,
    );
  }

  Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    state = state.copyWith(language: language);
  }

  Future<void> setFontSize(String fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontSize', fontSize);
    state = state.copyWith(fontSize: fontSize);
  }

  Future<void> setAppMode(String appMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appMode', appMode);
    state = state.copyWith(appMode: appMode);
  }

  Future<void> setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme);
    state = state.copyWith(theme: theme);
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
