import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/field_control.dart';
import 'package:scss_grid/controls/title_control.dart';
import 'package:scss_grid/model/cell.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 300, height: 60, child: child)));

void main() {
  test('dataKey returns the field key, null for a title', () {
    const field = Cell(id: 'f', col: 0, row: 0, colSpan: 4, type: 'field',
        props: {'label': 'L', 'key': 'site_name'});
    const title = Cell(id: 't', col: 0, row: 0, colSpan: 4, type: 'title',
        props: {'text': 'Hi'});
    expect(FieldControl().dataKey(field), 'site_name');
    expect(TitleControl().dataKey(title), isNull);
  });

  testWidgets('field fillWidget shows the current value and reports edits',
      (tester) async {
    Object? captured;
    const cell = Cell(id: 'f', col: 0, row: 0, colSpan: 4, type: 'field',
        props: {'label': 'Site', 'key': 'site_name', 'labelCols': 1});
    await tester.pumpWidget(_host(
      FieldControl().fillWidget(cell, 'Old', (v) => captured = v),
    ));
    expect(find.text('Site'), findsOneWidget); // label rendered
    expect(find.text('Old'), findsOneWidget); // current value prefilled

    await tester.enterText(find.byType(TextFormField), 'New');
    expect(captured, 'New');
  });

  testWidgets('title fillWidget is read-only (its preview text, no input)',
      (tester) async {
    const cell = Cell(id: 't', col: 0, row: 0, colSpan: 4, type: 'title',
        props: {'text': 'Form Title'});
    await tester.pumpWidget(_host(
      TitleControl().fillWidget(cell, null, (_) {}),
    ));
    expect(find.text('Form Title'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
}
