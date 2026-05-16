import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rice_agent/main.dart';
import 'package:rice_agent/db/database.dart';
import 'package:rice_agent/widgets/error_boundary.dart';


void main() {
  testWidgets('HomeScreen loads without error', (WidgetTester tester) async {
    final db = AppDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ErrorBoundary(
          child: RiceAgentApp(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Oops! Something went wrong'), findsNothing);
    await db.close();
  });
}
