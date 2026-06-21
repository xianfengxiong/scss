import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/cell_inspector.dart';
import 'package:scss_grid/controls/field_control.dart';
import 'package:scss_grid/model/cell.dart';

void main() {
  testWidgets('inspector shows propEditor, steps colSpan, and deletes',
      (tester) async {
    int? newSpan;
    var deleted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CellInspector(
          cell: const Cell(id: 'f', col: 0, row: 0, colSpan: 2, type: 'field',
              props: {'label': 'L', 'valueType': 'text'}),
          spec: FieldControl(),
          maxColSpan: 4,
          onPropsChanged: (_) {},
          onColSpanChanged: (v) => newSpan = v,
          onDelete: () => deleted = true,
        ),
      ),
    ));
    expect(find.byType(TextFormField), findsOneWidget); // field label editor
    expect(find.text('Width: 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('colspan-inc')));
    expect(newSpan, 3);

    await tester.tap(find.byKey(const ValueKey('cell-delete')));
    expect(deleted, isTrue);
  });
}
