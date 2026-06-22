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
    expect(find.byType(TextFormField), findsOneWidget); // label text editor
    expect(find.text('Width: 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('colspan-inc')));
    expect(newSpan, 3);

    await tester.tap(find.byKey(const ValueKey('cell-delete')));
    expect(deleted, isTrue);
  });
}
