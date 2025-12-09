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

    // Verify that the splash screen or home screen is shown.
    // Note: If you have a splash screen, you might need to pump enough time for it to navigate.
    // For now, let's assume it goes to HomeScreen or check for the app title if it's in the AppBar.

    // Depending on your Splash logic, you might see 'RiceAgent' immediately or after a delay.
    // Let's verify the Home Screen elements if possible.
    // Since HomeScreen has 'New Order', 'Customers', etc.

    // Check for AppBar title
    expect(find.text('RiceAgent'), findsOneWidget);

    // Check for 'New Order' button
    expect(find.text('New Order'), findsOneWidget);
    expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);
  });
}
