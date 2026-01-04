import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';
import 'db/database.dart';
import 'services/seed_service.dart';
import 'theme.dart';
import 'providers/settings_provider.dart';

/// Global database provider for Drift/SQLite access
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    final db = AppDatabase();

    runApp(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const RiceAgentApp(),
    ));

    // Seed sample data in the background after app starts to ensure speed
    Future(() async {
      try {
        await SeedService.seedDatabase(db);
      } catch (e) {
        debugPrint('Background seeding failed: $e');
      }
    });
  } catch (e) {
    debugPrint('Fatal Startup Error: $e');
  }
}

/// Root application widget - now responds to settings changes
class RiceAgentApp extends ConsumerWidget {
  const RiceAgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    // Build theme based on settings
    final baseTheme =
        settings.isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

    // Apply font scaling
    final scaledTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(
        fontSizeFactor: settings.fontScale,
      ),
    );

    return MaterialApp(
      title: 'RiceAgent',
      debugShowCheckedModeBanner: false,
      theme: scaledTheme,
      home: const SplashScreen(),
    );
  }
}
