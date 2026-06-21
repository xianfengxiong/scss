import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/controls/title_control.dart';
import 'package:scss_grid/controls/field_control.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 200, height: 40, child: child)));

void main() {
  testWidgets('TitleControl preview shows its text bold', (tester) async {
    await tester.pumpWidget(_host(TitleControl().previewWidget(
        const Cell(id: 't', col: 0, row: 0, type: 'title', props: {'text': 'My Title'}))));
    expect(find.text('My Title'), findsOneWidget);
  });

  testWidgets('FieldControl preview shows its label', (tester) async {
    await tester.pumpWidget(_host(FieldControl().previewWidget(
        const Cell(id: 'f', col: 0, row: 0, colSpan: 4, type: 'field',
            props: {'label': 'Site Name', 'key': 'site_name', 'labelCols': 1}))));
    expect(find.text('Site Name'), findsOneWidget);
  });
}
