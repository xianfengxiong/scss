import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/text_control.dart';
import 'package:scss_grid/controls/number_control.dart';
import 'package:scss_grid/model/cell.dart';

const _textCell = Cell(id: 't', col: 0, row: 0, colSpan: 4, type: 'text',
    props: {'key': 'site_name', 'hint': ''});
const _numCell = Cell(id: 'n', col: 0, row: 0, colSpan: 4, type: 'number',
    props: {'key': 'count', 'unit': 'm'});

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 240, height: 40, child: child)));

void main() {
  test('TextControl: type, defaultProps, dataKey', () {
    final c = TextControl();
    expect(c.type, 'text');
    expect(c.defaultProps(), {'key': 'text', 'hint': ''});
    expect(c.dataKey(_textCell), 'site_name');
  });

  test('NumberControl: type, defaultProps, dataKey', () {
    final c = NumberControl();
    expect(c.type, 'number');
    expect(c.defaultProps(), {'key': 'number', 'unit': ''});
    expect(c.dataKey(_numCell), 'count');
  });

  testWidgets('TextControl fillWidget shows current value and reports edits',
      (tester) async {
    Object? captured;
    await tester.pumpWidget(_host(
      TextControl().fillWidget(_textCell, 'Old', (v) => captured = v),
    ));
    expect(find.text('Old'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'New');
    expect(captured, 'New');
  });

  testWidgets('NumberControl fillWidget uses a numeric keyboard', (tester) async {
    await tester.pumpWidget(_host(
      NumberControl().fillWidget(_numCell, '3', (_) {}),
    ));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.number);
  });
}
