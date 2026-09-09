import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remell/shared/bottom_sheets/create_task_sheet.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => child,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('CreateTaskSheet pre-selects Quick Note by default', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        const CreateTaskSheet(initialIsQuickNote: true),
      ),
    );

    // Open bottom sheet
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify it shows Quick Note header
    expect(find.text('create a quick note.'), findsOneWidget);

    // Find the 'quick note' pill
    final quickNotePill = find.text('quick note');
    expect(quickNotePill, findsOneWidget);

    // Verify 'daily task' pill is also there
    expect(find.text('daily task'), findsOneWidget);
  });

  testWidgets('CreateTaskSheet pre-selects Daily Task when initialIsQuickNote is false', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        const CreateTaskSheet(initialIsQuickNote: false),
      ),
    );

    // Open bottom sheet
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // In daily task mode, 'create a quick note.' should NOT be visible
    expect(find.text('create a quick note.'), findsNothing);

    // It should have daily task specific text, e.g. 'deadline:'
    expect(find.text('deadline:'), findsOneWidget);
  });
}
