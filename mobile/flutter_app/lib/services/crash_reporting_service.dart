import 'package:flutter/foundation.dart';

/// CrashReportingService - Cloud error reporting for production
///
/// ## How This Is Useful:
///
/// When your app crashes in production (on your dad's phone or customers' phones),
/// you currently have NO WAY to know what went wrong. With cloud crash reporting:
///
/// 1. **Automatic Error Capture** - Every crash is sent to a dashboard
/// 2. **Stack Traces** - See exactly which line caused the crash
/// 3. **User Context** - Know which screen/action caused the issue
/// 4. **Trend Analysis** - See which errors happen most often
/// 5. **Real-time Alerts** - Get notified when crashes spike
///
/// ## Setup Options:
///
/// ### Option 1: Sentry (Recommended - Free for small apps)
/// 1. Go to https://sentry.io and create free account
/// 2. Create a Flutter project
/// 3. Copy DSN (looks like: https://xxx@sentry.io/yyy)
/// 4. Add to pubspec.yaml: sentry_flutter: ^8.0.0
/// 5. Initialize in main.dart with your DSN
///
/// ### Option 2: Firebase Crashlytics
/// 1. Go to https://console.firebase.google.com
/// 2. Create project, add Android app
/// 3. Download google-services.json
/// 4. Add firebase_crashlytics package
/// 5. More complex setup but integrates with Firebase ecosystem
///
/// ## Current Implementation:
/// This service provides a ready-to-use interface. Just uncomment the Sentry
/// code after adding the package and your DSN.

class CrashReportingService {
  static bool _initialized = false;
  static String? _dsn;

  /// Initialize crash reporting
  /// Call this at app startup BEFORE runApp()
  ///
  /// Example:
  /// ```dart
  /// await CrashReportingService.init(
  ///   dsn: 'https://your-dsn@sentry.io/your-project',
  /// );
  /// ```
  static Future<void> init({String? dsn}) async {
    if (_initialized) return;

    _dsn = dsn;

    // SETUP: Uncomment after adding sentry_flutter to pubspec.yaml
    // if (dsn != null && dsn.isNotEmpty) {
    //   await SentryFlutter.init(
    //     (options) {
    //       options.dsn = dsn;
    //       options.tracesSampleRate = 1.0;
    //       options.environment = kReleaseMode ? 'production' : 'development';
    //     },
    //   );
    // }

    _initialized = true;
    debugPrint(
        '[CrashReporting] Initialized${_dsn != null ? ' with Sentry' : ' (local only)'}');
  }

  /// Report an error to the crash reporting service
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await riskyOperation();
  /// } catch (e, stack) {
  ///   CrashReportingService.reportError(e, stack, context: 'Saving order');
  /// }
  /// ```
  static Future<void> reportError(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? extras,
  }) async {
    // Always log locally
    debugPrint('[CrashReporting] Error: $error');
    debugPrint('[CrashReporting] Context: $context');
    if (stackTrace != null) {
      debugPrint('[CrashReporting] Stack: $stackTrace');
    }

    // SETUP: Uncomment after adding sentry_flutter
    // if (_dsn != null) {
    //   await Sentry.captureException(
    //     error,
    //     stackTrace: stackTrace,
    //     withScope: (scope) {
    //       if (context != null) {
    //         scope.setTag('context', context);
    //       }
    //       if (extras != null) {
    //         extras.forEach((key, value) {
    //           scope.setExtra(key, value);
    //         });
    //       }
    //     },
    //   );
    // }
  }

  /// Report a non-fatal issue (breadcrumb)
  ///
  /// Example:
  /// ```dart
  /// CrashReportingService.logBreadcrumb(
  ///   'User tapped New Order',
  ///   category: 'navigation',
  /// );
  /// ```
  static void logBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  }) {
    debugPrint('[CrashReporting] Breadcrumb: $message');

    // SETUP: Uncomment after adding sentry_flutter
    // if (_dsn != null) {
    //   Sentry.addBreadcrumb(Breadcrumb(
    //     message: message,
    //     category: category,
    //     data: data,
    //     timestamp: DateTime.now(),
    //   ));
    // }
  }

  /// Set user context for error reports
  ///
  /// Example:
  /// ```dart
  /// CrashReportingService.setUser(
  ///   id: 'shop_123',
  ///   name: 'Galaxy Rice Mill',
  /// );
  /// ```
  static void setUser({
    String? id,
    String? name,
    String? email,
  }) {
    debugPrint('[CrashReporting] User set: $name ($id)');

    // SETUP: Uncomment after adding sentry_flutter
    // if (_dsn != null) {
    //   Sentry.configureScope((scope) {
    //     scope.setUser(SentryUser(
    //       id: id,
    //       username: name,
    //       email: email,
    //     ));
    //   });
    // }
  }

  /// Capture a message (for non-error events)
  static void captureMessage(String message, {String? level}) {
    debugPrint('[CrashReporting] Message: $message');

    // SETUP: Uncomment after adding sentry_flutter
    // if (_dsn != null) {
    //   Sentry.captureMessage(message, level: SentryLevel.info);
    // }
  }

  /// Check if crash reporting is active
  static bool get isActive => _dsn != null && _initialized;
}

/// Quick guide for enabling Sentry:
///
/// 1. Add to pubspec.yaml:
///    ```yaml
///    dependencies:
///      sentry_flutter: ^8.0.0
///    ```
///
/// 2. Get your DSN from https://sentry.io
///
/// 3. Update main.dart:
///    ```dart
///    void main() async {
///      await CrashReportingService.init(
///        dsn: 'https://your-dsn@sentry.io/project',
///      );
///
///      runZonedGuarded(() {
///        runApp(const MyApp());
///      }, (error, stack) {
///        CrashReportingService.reportError(error, stack);
///      });
///    }
///    ```
///
/// 4. That's it! Errors will now appear in your Sentry dashboard.
