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

  testWidgets('TitleControl preview scales text to fit a short cell (FittedBox)',
      (tester) async {
    await tester.pumpWidget(_host(TitleControl().previewWidget(const Cell(
        id: 't', col: 0, row: 0, type: 'title', props: {'text': 'My Title'}))));
    // FittedBox scale-down keeps the whole title inside the (short) cell instead
    // of clipping it vertically when the page is scaled down to phone width.
    expect(find.ancestor(of: find.text('My Title'), matching: find.byType(FittedBox)),
        findsOneWidget);
  });

  testWidgets('LabelControl preview tightens line height (height:1.0) for optical centering',
      (tester) async {
    await tester.pumpWidget(_host(LabelControl().previewWidget(const Cell(
        id: 'l', col: 0, row: 0, colSpan: 3, type: 'label',
        props: {'text': 'Site Name', 'align': 'left', 'bold': false}))));
    // A tight line box lets the single line sit at the true vertical centre
    // (default leaves empty descent space that pushes the glyph up).
    expect(tester.widget<Text>(find.text('Site Name')).style?.height, 1.0);
  });

  testWidgets('LabelControl preview shows its text', (tester) async {
    await tester.pumpWidget(_host(LabelControl().previewWidget(
        const Cell(id: 'l', col: 0, row: 0, colSpan: 3, type: 'label',
            props: {'text': 'Site Name', 'align': 'left', 'bold': false}))));
    expect(find.text('Site Name'), findsOneWidget);
  });

  testWidgets('TitleControl fillWidget is read-only and dataKey is null',
      (tester) async {
    const titleCell = Cell(
        id: 't2', col: 0, row: 0, type: 'title', props: {'text': 'Form Title'});
    await tester.pumpWidget(_host(
        TitleControl().fillWidget(titleCell, null, (_) {})));
    expect(find.text('Form Title'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(TitleControl().dataKey(titleCell), isNull);
  });
}
