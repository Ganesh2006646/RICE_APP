import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'screens/splash_screen.dart';
import 'db/database.dart';
import 'theme.dart';
import 'providers/settings_provider.dart';
import 'services/backup_service.dart';
import 'services/crash_reporting_service.dart';
import 'services/product_seeding_service.dart';
import 'widgets/error_boundary.dart';

/// Global database provider for Drift/SQLite access
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

void main() async {
  // Initialize global error handler first
  GlobalErrorHandler.init();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize crash reporting (uncomment DSN after setting up Sentry)
  // To enable: Go to sentry.io, create project, paste DSN below
  await CrashReportingService.init(
      // dsn: 'https://your-dsn@sentry.io/your-project', // Uncomment with your DSN
      );

  // Run app in a zone to catch async errors
  runZonedGuarded(
    () async {
      try {
        // Apply any staged DB restore before opening Drift connection.
        await BackupService.applyPendingRestoreIfAny();

        final db = AppDatabase();

        // Seed initial products if empty
        await ProductSeedingService.seedInitialProducts(db);

        // Trigger auto-backup before app starts (non-blocking)
        _triggerAutoBackup();

        runApp(ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const ErrorBoundary(
            child: RiceAgentApp(),
          ),
        ));
      } catch (e, stack) {
        debugPrint('Fatal Startup Error: $e');
        GlobalErrorHandler.logError(e, stack);
        CrashReportingService.reportError(e, stack, context: 'App Startup');
        runApp(const _StartupErrorApp());
      }
    },
    (error, stack) {
      // Catch any async errors not caught by Flutter framework
      debugPrint('[ZoneError] Uncaught async error: $error');
      GlobalErrorHandler.logError(error, stack);
      CrashReportingService.reportError(error, stack, context: 'Async Zone');
    },
  );
}

/// Trigger auto-backup silently during startup
Future<void> _triggerAutoBackup() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? true;
    await BackupService.performAutoBackupIfNeeded(autoBackupEnabled);
  } catch (e) {
    debugPrint('[Main] Auto-backup trigger failed: $e');
  }
}

/// Root application widget - now responds to settings changes
class RiceAgentApp extends ConsumerWidget {
  const RiceAgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    // Build theme based on settings
    final baseTheme = AppTheme.lightTheme;

    // Apply font scaling
    final scaledTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(
        fontSizeFactor: settings.fontScale,
      ),
    );

    return MaterialApp(
      title: 'Galaxy E-Orders',
      debugShowCheckedModeBanner: false,
      theme: scaledTheme,
      // Pass language to locale for system components
      locale: Locale(settings.language.localeCode),
      home: const SplashScreen(),
    );
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                SizedBox(height: 12),
                Text(
                  'Unable to start the app.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  'Please restart and check logs in settings.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
