import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/grid_canvas.dart';
import 'package:scss_grid/controls/registry.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _tpl(List<Cell> cells) => Template(
      id: 't',
      name: 'n',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 5, yMm: 5, cols: 4, rows: 4, colWidthMm: 20, rowHeightMm: 8),
      cells: cells,
    );

void main() {
  testWidgets('unknown control type renders a visible placeholder',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: GridCanvas(
            template: _tpl(const [
              Cell(id: 'u', col: 0, row: 0, colSpan: 4, type: 'mystery'),
            ]),
            registry: ControlRegistry(), // empty -> 'mystery' unregistered
          ),
        ),
      ),
    ));
    expect(find.textContaining('mystery'), findsOneWidget);
  });

  testWidgets('selectedId draws exactly one highlight', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: GridCanvas(
            template: _tpl(const [
              Cell(id: 'a', col: 0, row: 0, colSpan: 4, type: 'text',
                  props: {'key': 'k', 'hint': ''}),
            ]),
            registry: buildDefaultRegistry(),
            selectedId: 'a',
          ),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('cell-highlight')), findsOneWidget);
  });
}
