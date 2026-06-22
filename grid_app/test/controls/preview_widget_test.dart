import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/controls/title_control.dart';
import 'package:scss_grid/controls/label_control.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 200, height: 40, child: child)));

void main() {
  testWidgets('TitleControl preview shows its text bold', (tester) async {
    await tester.pumpWidget(_host(TitleControl().previewWidget(
        const Cell(id: 't', col: 0, row: 0, type: 'title', props: {'text': 'My Title'}))));
    expect(find.text('My Title'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
          (w) => w is Text && w.style?.fontWeight == FontWeight.bold),
      findsOneWidget,
    );
  });

  testWidgets('LabelControl preview shows its text', (tester) async {
    await tester.pumpWidget(_host(LabelControl().previewWidget(
        const Cell(id: 'l', col: 0, row: 0, colSpan: 3, type: 'label',
            props: {'text': 'Site Name', 'align': 'left', 'bold': false}))));
    expect(find.text('Site Name'), findsOneWidget);
  });
}
