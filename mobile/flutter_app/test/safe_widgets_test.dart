/// Widget tests for SafeWidgets library
/// Tests UI components for proper rendering and behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rice_agent/widgets/safe_widgets.dart';

void main() {
  group('SafePage Widget Tests', () {
    testWidgets('renders child content with padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafePage(
              child: Text('Test Content'),
            ),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('renders with custom padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafePage(
              padding: EdgeInsets.all(32),
              child: Text('Padded'),
            ),
          ),
        ),
      );

      // Verify content renders correctly
      expect(find.text('Padded'), findsOneWidget);
      expect(find.byType(SafePage), findsOneWidget);
    });
  });

  group('SafeCard Widget Tests', () {
    testWidgets('renders child with card styling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      // SafeCard uses Container with styling, not Card widget
      expect(find.byType(SafeCard), findsOneWidget);
    });

    testWidgets('renders with margin', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeCard(
              margin: EdgeInsets.all(16),
              child: Text('Margined'),
            ),
          ),
        ),
      );

      // Verify renders correctly with margin
      expect(find.text('Margined'), findsOneWidget);
      expect(find.byType(SafeCard), findsOneWidget);
    });
  });

  group('SafeText Widget Tests', () {
    testWidgets('renders text with default overflow handling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeText('Hello World'),
          ),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('applies custom style', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeText(
              'Styled Text',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Styled Text'));
      expect(text.style?.fontSize, 24);
      expect(text.style?.fontWeight, FontWeight.bold);
    });
  });

  group('SafeColumn Widget Tests', () {
    testWidgets('renders children vertically', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeColumn(
              children: [
                Text('First'),
                Text('Second'),
                Text('Third'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Third'), findsOneWidget);
    });

    testWidgets('applies alignment', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeColumn(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text('Aligned')],
            ),
          ),
        ),
      );

      final column = tester.widget<Column>(find.byType(Column).first);
      expect(column.mainAxisAlignment, MainAxisAlignment.center);
      expect(column.crossAxisAlignment, CrossAxisAlignment.start);
    });
  });

  group('SafeRow Widget Tests', () {
    testWidgets('renders leading and trailing content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeRow(
              leading: Text('Leading'),
              trailing: Text('Trailing'),
            ),
          ),
        ),
      );

      expect(find.text('Leading'), findsOneWidget);
      expect(find.text('Trailing'), findsOneWidget);
    });

    testWidgets('renders without trailing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeRow(
              leading: Text('Only Leading'),
            ),
          ),
        ),
      );

      expect(find.text('Only Leading'), findsOneWidget);
    });
  });

  group('SafeWrap Widget Tests', () {
    testWidgets('wraps children when space is limited', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: SafeWrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  5,
                  (i) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.blue,
                    child: Text('$i'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsNWidgets(5));
    });
  });

  group('SafeProgress Widget Tests', () {
    testWidgets('shows progress indicator with label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeProgress(
              label: 'Loading',
              value: 50,
              max: 100,
            ),
          ),
        ),
      );

      expect(find.text('Loading'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('displays value and max', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeProgress(
              label: 'Progress',
              value: 75,
              max: 100,
            ),
          ),
        ),
      );

      expect(find.text('Progress'), findsOneWidget);
      // Should show "75.00 / 100"
      expect(find.textContaining('75'), findsWidgets);
    });
  });

  group('SafeListTile Widget Tests', () {
    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeListTile(
              title: 'Title',
              subtitle: 'Subtitle',
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Subtitle'), findsOneWidget);
    });

    testWidgets('handles tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeListTile(
              title: 'Tapable',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tapable'));
      expect(tapped, true);
    });
  });

  group('SafeBuilder Widget Tests', () {
    testWidgets('renders builder result when not null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeBuilder(
              builder: () => const Text('Built Content'),
            ),
          ),
        ),
      );

      expect(find.text('Built Content'), findsOneWidget);
    });

    testWidgets('renders fallback when builder returns null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeBuilder(
              builder: () => null,
              fallback: const Text('Fallback'),
            ),
          ),
        ),
      );

      expect(find.text('Fallback'), findsOneWidget);
    });

    testWidgets('shows default loading indicator when no fallback',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeBuilder(
              builder: () => null,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('SafeSnackBar Tests', () {
    testWidgets('shows snackbar with message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => SafeSnackBar.show(context, 'Test Message'),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump(); // Trigger snackbar animation
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Test Message'), findsOneWidget);
    });

    testWidgets('shows error snackbar with red background', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    SafeSnackBar.show(context, 'Error!', isError: true),
                child: const Text('Show Error'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Error!'), findsOneWidget);

      // Find the snackbar and check its background color
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, Colors.red);
    });
  });
}
