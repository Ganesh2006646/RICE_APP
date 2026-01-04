import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import '../services/translation_service.dart';

/// Splash screen with animated branding
/// Auto-navigates to Home after animation completes
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  /// Navigate to home screen after a delay
  Future<void> _navigateToHome() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withValues(alpha: 0.1),
              ),
              padding: const EdgeInsets.all(20),
              child: Image.asset(
                'assets/images/sri_balaji_logo.png',
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 40),

            // Mill Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'mill_full_name'.tr(ref),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                  letterSpacing: 1.1,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(
                height: 60), // Added SizedBox to separate from indicator
            // Loading indicator
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor
                    .withOpacity(0.6)), // Changed withValues to withOpacity
              ),
            ),
          ],
        ),
      ),
    );
  }
}
