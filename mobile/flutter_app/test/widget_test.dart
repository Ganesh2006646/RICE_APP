// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rice_agent/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We need to wrap the app in a ProviderScope because it uses Riverpod.
    await tester.pumpWidget(const ProviderScope(child: RiceAgentApp()));

    // The app starts with a SplashScreen which has a loading indicator
    // Verify the splash screen is showing (it has a CircularProgressIndicator)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for splash screen animation and navigation
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // After splash, we should be on the HomeScreen
    // HomeScreen has a Scaffold with bottom navigation or quick action buttons
    expect(find.byType(Scaffold), findsWidgets);
  });
}
