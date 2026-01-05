import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';
import 'db/database.dart';
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
      title: 'Galaxy E-Orders',
      debugShowCheckedModeBanner: false,
      theme: scaledTheme,
      // Pass language to locale for system components (though manual translation is used primary)
      locale: Locale(settings.language == 'Telugu'
          ? 'te'
          : (settings.language == 'Hindi'
              ? 'hi'
              : (settings.language == 'Tamil' ? 'ta' : 'en'))),
      home: const SplashScreen(),
    );
  }
}
