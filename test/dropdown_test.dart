import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabang/theme.dart';
import 'package:tabang/widgets/tabang_dropdown.dart';

void main() {
  List<DropdownMenuItem<String>> items(List<String> values) => [
    for (final value in values)
      DropdownMenuItem(value: value, child: Text(value)),
  ];

  testWidgets('opens, shows a search box for long lists, and selects', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: TabangDropdown<String>(
                items: items(const [
                  'One',
                  'Two',
                  'Three',
                  'Four',
                  'Five',
                  'Six',
                  'Seven',
                  'Eight',
                  'Nine',
                ]),
                onChanged: (value) => picked = value,
                decoration: const InputDecoration(labelText: 'Pick one'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Closed: the hint stands in for the value.
    expect(find.text('Select'), findsOneWidget);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    // Nine items is past the threshold, so the list is searchable.
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Nine');
    await tester.pumpAndSettle();
    expect(find.text('One'), findsNothing);

    // Tap the row, not the search box (which also contains "Nine").
    await tester.tap(
      find.descendant(of: find.byType(ListView), matching: find.text('Nine')),
    );
    await tester.pumpAndSettle();

    expect(picked, 'Nine');
    // The chosen value is now the field's label.
    expect(find.text('Nine'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short lists skip the search box and validate inside a form', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(
          body: Form(
            key: formKey,
            child: TabangDropdown<String>(
              items: items(const ['One', 'Two']),
              decoration: const InputDecoration(labelText: 'Pick one'),
              validator: (value) => value == null ? 'Choose something' : null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();

    expect(formKey.currentState!.validate(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the null "All" option can be chosen, not just dismissed', (
    tester,
  ) async {
    String? picked = 'sentinel';
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(
          body: TabangDropdown<String?>(
            initialValue: 'Open',
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('All states')),
              DropdownMenuItem<String?>(value: 'Open', child: Text('Open')),
            ],
            decoration: const InputDecoration(labelText: 'State'),
            onChanged: (value) {
              picked = value;
              calls++;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All states'));
    await tester.pumpAndSettle();

    // Reset must actually fire: the null value is a real choice, not a dismiss.
    expect(calls, 1);
    expect(picked, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing the sheet leaves the selection unchanged', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(
          body: TabangDropdown<String?>(
            initialValue: 'Open',
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('All states')),
              DropdownMenuItem<String?>(value: 'Open', child: Text('Open')),
            ],
            decoration: const InputDecoration(labelText: 'State'),
            onChanged: (_) => calls++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    // Tap the barrier above the sheet to dismiss it.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a count in the field and beside every option', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: TabangDropdown<String?>(
                initialValue: 'Open',
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All states'),
                  ),
                  DropdownMenuItem<String?>(value: 'Open', child: Text('Open')),
                  DropdownMenuItem<String?>(
                    value: 'Closed',
                    child: Text('Closed'),
                  ),
                ],
                countFor: (value) => switch (value) {
                  null => 9,
                  'Open' => 4,
                  'Closed' => 0,
                  _ => null,
                },
                decoration: const InputDecoration(labelText: 'State'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The closed field carries the estimate for the current selection.
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    Finder inSheet(String text) =>
        find.descendant(of: find.byType(ListView), matching: find.text(text));
    // Every row carries its own estimate, including a zero-result choice.
    expect(inSheet('9'), findsOneWidget);
    expect(inSheet('4'), findsOneWidget);
    expect(inSheet('0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
