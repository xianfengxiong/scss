import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/controls/control_spec.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _empty() => Template(
      id: 'e',
      name: 'Empty',
      page: const PageSize.a4(),
      pages: [
        TemplatePage(
          grid: GridFrame.uniform(
              xMm: 10, yMm: 10, cols: 12, rows: 16,
              colWidthMm: 15, rowHeightMm: 8),
          cells: const [],
        ),
      ],
    );

void main() {
  testWidgets('palette items are draggable', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BuilderScreen(
          template: _empty(),
          registry: buildDefaultRegistry(),
          store: InMemoryTemplateStore()),
    ));
    // one LongPressDraggable per registered control (Title, Label, Text, Number, Coordinate).
    expect(find.byType(LongPressDraggable<ControlSpec>),
        findsNWidgets(buildDefaultRegistry().all.length));
  });

  testWidgets('long-press-dragging a palette control onto the grid places it there',
      (tester) async {
    final store = InMemoryTemplateStore();
    await tester.pumpWidget(MaterialApp(
      home: BuilderScreen(
          template: _empty(),
          registry: buildDefaultRegistry(),
          store: store),
    ));
    await tester.pumpAndSettle();

    final textItem = find.text('Text');
    final start = tester.getCenter(textItem);
    // Target a point inside the canvas, below the title band, in the grid area.
    final canvasCenter = tester.getCenter(find.byType(BuilderScreen));

    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 600)); // trigger long-press
    await gesture.moveTo(canvasCenter);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    final saved = await store.get('e');
    expect(saved!.pages[0].cells, isNotEmpty); // a control was placed by the drop
  });
}
