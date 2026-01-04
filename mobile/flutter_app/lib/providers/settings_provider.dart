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
  final String invoicePrefix;

  const AppSettings({
    this.language = 'English',
    this.fontSize = 'Medium',
    this.appMode = 'Simple Mode',
    this.theme = 'Light',
    this.defaultDueDays = 7,
    this.millEmail = 'sbbrrm@gmail.com',
    this.invoicePrefix = 'SBRM-2024-',
  });

  AppSettings copyWith({
    String? language,
    String? fontSize,
    String? appMode,
    String? theme,
    int? defaultDueDays,
    String? millEmail,
    String? invoicePrefix,
  }) {
    return AppSettings(
      language: language ?? this.language,
      fontSize: fontSize ?? this.fontSize,
      appMode: appMode ?? this.appMode,
      theme: theme ?? this.theme,
      defaultDueDays: defaultDueDays ?? this.defaultDueDays,
      millEmail: millEmail ?? this.millEmail,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
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
      invoicePrefix: prefs.getString('invoice_prefix') ?? 'SBRM-2024-',
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

  Future<void> setInvoicePrefix(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('invoice_prefix', prefix);
    state = state.copyWith(invoicePrefix: prefix);
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
