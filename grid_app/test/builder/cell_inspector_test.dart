import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/cell_inspector.dart';
import 'package:scss_grid/controls/label_control.dart';
import 'package:scss_grid/model/cell.dart';

void main() {
  testWidgets('inspector shows propEditor, steps colSpan, and deletes',
      (tester) async {
    int? newSpan;
    var deleted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CellInspector(
          cell: const Cell(id: 'l', col: 0, row: 0, colSpan: 2, type: 'label',
              props: {'text': 'L', 'align': 'left', 'bold': false}),
          spec: LabelControl(),
          maxColSpan: 4,
          onPropsChanged: (_) {},
          onColSpanChanged: (v) => newSpan = v,
          onDelete: () => deleted = true,
        ),
      ),
    ));
    // Docked inspector starts collapsed; expand to reach the editor + stepper.
    await tester.tap(find.byKey(const ValueKey('inspector-toggle')));
    await tester.pump();
    expect(find.byType(TextFormField), findsOneWidget); // label text editor
    expect(find.text('Width: 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('colspan-inc')));
    expect(newSpan, 3);

    await tester.tap(find.byKey(const ValueKey('cell-delete')));
    expect(deleted, isTrue);
  });

  testWidgets('starts collapsed (docked); toggle expands then collapses',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CellInspector(
          cell: const Cell(id: 'l', col: 0, row: 0, colSpan: 2, type: 'label',
              props: {'text': 'L', 'align': 'left', 'bold': false}),
          spec: LabelControl(),
          maxColSpan: 4,
          onPropsChanged: (_) {},
          onColSpanChanged: (_) {},
          onDelete: () {},
        ),
      ),
    ));
    // Collapsed: header (label + delete) visible, but no editor / stepper.
    expect(find.text('Label'), findsOneWidget);
    expect(find.byKey(const ValueKey('cell-delete')), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byKey(const ValueKey('colspan-inc')), findsNothing);

    // Expand → editor + stepper appear.
    await tester.tap(find.byKey(const ValueKey('inspector-toggle')));
    await tester.pump();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.byKey(const ValueKey('colspan-inc')), findsOneWidget);

    // Collapse again → editor hidden.
    await tester.tap(find.byKey(const ValueKey('inspector-toggle')));
    await tester.pump();
    expect(find.byType(TextFormField), findsNothing);
  });
}
