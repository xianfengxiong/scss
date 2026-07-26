import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/fill/fill_canvas.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _tpl() => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 0, yMm: 0, cols: 12, rows: 4, colWidthMm: 15, rowHeightMm: 20),
      cells: const [
        Cell(id: 'title', col: 0, row: 0, colSpan: 12, type: 'title',
            props: {'text': 'Form'}),
        Cell(id: 'name_l', col: 0, row: 1, colSpan: 3, type: 'label',
            props: {'text': 'Site', 'align': 'left', 'bold': false}),
        Cell(id: 'name_v', col: 3, row: 1, colSpan: 9, type: 'text',
            props: {'key': 'site_name', 'hint': ''}),
      ],
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 210, height: 297, child: child),
        ),
      ),
    );

void main() {
  testWidgets('renders title text and a field input with its current value',
      (tester) async {
    await tester.pumpWidget(_host(FillCanvas(
      template: _tpl(),
      registry: buildDefaultRegistry(),
      data: const {'site_name': 'Gjirokaster'},
      onChanged: (_, __) {},
    )));
    expect(find.text('Form'), findsOneWidget); // read-only title
    expect(find.text('Site'), findsOneWidget); // label cell
    expect(find.text('Gjirokaster'), findsOneWidget); // prefilled value
  });

  testWidgets('editing a field reports (key, value) via onChanged',
      (tester) async {
    String? gotKey;
    Object? gotVal;
    await tester.pumpWidget(_host(FillCanvas(
      template: _tpl(),
      registry: buildDefaultRegistry(),
      data: const {},
      onChanged: (k, v) {
        gotKey = k;
        gotVal = v;
      },
    )));
    await tester.enterText(find.byType(TextFormField), 'Berat');
    expect(gotKey, 'site_name');
    expect(gotVal, 'Berat');
  });

  testWidgets('a wide short box fits the whole page (desktop window)',
      (tester) async {
    // 594x297: twice as wide as A4 at this height. Fit-to-width would blow
    // the page up to 594x840 (top slice only); fit-both keeps it 210x297.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 594,
            height: 297,
            // Center loosens the constraints, matching production
            // (FillScreen hosts the canvas as InteractiveViewer > Center).
            child: Center(
              child: FillCanvas(
                template: _tpl(),
                registry: buildDefaultRegistry(),
                data: const {},
                onChanged: (_, __) {},
              ),
            ),
          ),
        ),
      ),
    ));
    final page = tester.getSize(find.byType(FillCanvas));
    // The canvas box is given 594 wide, but the painted page inside must be
    // height-fitted: its Container child is 210x297.
    final container = tester.getSize(
      find.descendant(
          of: find.byType(FillCanvas), matching: find.byType(Container)).first,
    );
    expect(page.height, 297);
    expect(container.width, closeTo(210, 0.5));
    expect(container.height, closeTo(297, 0.5));
  });
}
