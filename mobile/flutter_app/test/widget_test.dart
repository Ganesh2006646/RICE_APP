// Widget tests for RiceAgent app
// These tests verify basic widget rendering without requiring database

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rice_agent/theme.dart';
import 'package:rice_agent/widgets/error_boundary.dart';

void main() {
  group('App Theme Tests', () {
    testWidgets('Light theme renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(child: Text('Light Theme Test')),
          ),
        ),
      );

      expect(find.text('Light Theme Test'), findsOneWidget);
    });

    testWidgets('Dark theme renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Center(child: Text('Dark Theme Test')),
          ),
        ),
      );

      expect(find.text('Dark Theme Test'), findsOneWidget);
    });
  });

  group('Error Boundary Tests', () {
    testWidgets('ErrorBoundary renders child normally',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ErrorBoundary(
            child: Scaffold(
              body: Center(child: Text('Normal Content')),
            ),
          ),
        ),
      );

      expect(find.text('Normal Content'), findsOneWidget);
      expect(find.byType(ErrorBoundary), findsOneWidget);
    });

    testWidgets('ErrorBoundary wraps content in widget tree',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ErrorBoundary(
            child: Scaffold(
              appBar: AppBar(title: const Text('Test App')),
              body: const Center(child: Text('Body Content')),
            ),
          ),
        ),
      );

      expect(find.text('Test App'), findsOneWidget);
      expect(find.text('Body Content'), findsOneWidget);
    });
  });
}
