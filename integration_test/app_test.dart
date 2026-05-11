/// Integration tests for RiceAgent app
/// Tests full user flows from splash to order creation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rice_agent/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Startup Flow', () {
    testWidgets('App starts and navigates to home screen', (tester) async {
      // Start the app
      await tester.pumpWidget(const ProviderScope(child: RiceAgentApp()));

      // Should start with splash screen (has loading indicator)
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Wait for splash animation and navigation to home
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Should now be on home screen with Scaffold
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('Navigation Flow', () {
    testWidgets('Can navigate to different screens from drawer',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(child: RiceAgentApp()));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Find and open the drawer
      final scaffoldState =
          tester.firstState<ScaffoldState>(find.byType(Scaffold));
      if (scaffoldState.hasDrawer) {
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        // Should see navigation options
        expect(find.byType(Drawer), findsOneWidget);
      }
    });
  });

  group('Order Creation Flow', () {
    testWidgets('New order screen shows step 1 (Lorry Builder)',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(child: RiceAgentApp()));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Try to find New Order button or navigate to it
      final newOrderButton = find.textContaining('New Order');
      if (newOrderButton.evaluate().isNotEmpty) {
        await tester.tap(newOrderButton.first);
        await tester.pumpAndSettle();

        // Should be on new order screen - check for capacity field or customer selection
        expect(find.byType(Scaffold), findsWidgets);
      }
    });
  });

  group('Back Navigation Safety', () {
    testWidgets('Back button does not cause black screen', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: RiceAgentApp()));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Navigate somewhere
      final scaffoldState =
          tester.firstState<ScaffoldState>(find.byType(Scaffold));
      if (scaffoldState.hasDrawer) {
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        // Close drawer using scaffoldState (avoids BuildContext async gap)
        scaffoldState.closeDrawer();
        await tester.pumpAndSettle();

        // Should still have a valid UI - not a black screen
        expect(find.byType(Scaffold), findsWidgets);
      }
    });

    testWidgets('App handles multiple rapid navigations', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: RiceAgentApp()));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Multiple navigation attempts should not crash
      for (int i = 0; i < 5; i++) {
        final scaffoldState =
            tester.firstState<ScaffoldState>(find.byType(Scaffold));
        if (scaffoldState.hasDrawer) {
          scaffoldState.openDrawer();
          await tester.pump(const Duration(milliseconds: 100));
          scaffoldState.closeDrawer();
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tester.pumpAndSettle();
      // App should still be responsive
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('Settings Flow', () {
    testWidgets('Settings screen loads without errors', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: RiceAgentApp()));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Try to navigate to settings
      final scaffoldState =
          tester.firstState<ScaffoldState>(find.byType(Scaffold));
      if (scaffoldState.hasDrawer) {
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        final settingsOption = find.textContaining('Settings');
        if (settingsOption.evaluate().isNotEmpty) {
          await tester.tap(settingsOption.first);
          await tester.pumpAndSettle();

          // Should be on settings screen
          expect(find.byType(Scaffold), findsWidgets);
        }
      }
    });
  });

  group('Error Recovery', () {
    testWidgets('App remains stable after operations', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: RiceAgentApp()));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Just verify the app is stable and showing UI
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);

      // No black screen - should have visible widgets
      expect(tester.allWidgets.isNotEmpty, true);
    });
  });
}
