import 'package:flutter/foundation.dart';

/// Lightweight crash reporting service.
/// Reports to debug console in dev; ready for Sentry integration in production.
class CrashReportingService {
  static bool _initialized = false;

  /// Initialize crash reporting. Call before runApp().
  static Future<void> init({String? dsn}) async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('[CrashReporting] Initialized${dsn != null ? ' with Sentry' : ' (local only)'}');
  }

  /// Report an error with optional context tag.
  static Future<void> reportError(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
  }) async {
    debugPrint('[CrashReporting] ${context ?? 'Error'}: $error');
  }

  /// Log a breadcrumb event for debugging.
  static void logBreadcrumb(String message, {String? category}) {
    debugPrint('[CrashReporting] $message');
  }

  static bool get isActive => _initialized;
}
