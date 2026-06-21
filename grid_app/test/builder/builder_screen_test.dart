import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/builder/grid_canvas.dart';
import 'package:scss_grid/builder/control_palette.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _empty() => Template(
      id: 'e',
      name: 'Empty',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 10, yMm: 10, cols: 12, rows: 16, colWidthMm: 15, rowHeightMm: 8),
      cells: const [],
    );

void main() {
  testWidgets('shows name, grid size, canvas; Save persists', (tester) async {
    final store = InMemoryTemplateStore();
    final t = _empty();
    await tester.pumpWidget(MaterialApp(
      home: BuilderScreen(
          template: t, registry: buildDefaultRegistry(), store: store),
    ));
    expect(find.text('Empty'), findsOneWidget);
    expect(find.byType(GridCanvas), findsOneWidget);
    expect(find.byType(ControlPalette), findsOneWidget);

    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    expect((await store.get(t.id))!.id, t.id);
  });

  testWidgets('tapping a palette control adds a cell to the template',
      (tester) async {
    final store = InMemoryTemplateStore();
    await tester.pumpWidget(MaterialApp(
      home: BuilderScreen(
          template: _empty(), registry: buildDefaultRegistry(), store: store),
    ));
    await tester.tap(find.text('Field')); // palette item
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    final saved = await store.get('e');
    expect(saved!.cells.length, 1);
    expect(saved.cells.single.type, 'field');
  });

  testWidgets('adding then deleting a control leaves the template empty',
      (tester) async {
    final store = InMemoryTemplateStore();
    await tester.pumpWidget(MaterialApp(
      home: BuilderScreen(
          template: _empty(), registry: buildDefaultRegistry(), store: store),
    ));
    await tester.tap(find.text('Field')); // palette add -> auto-selects, inspector shows
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cell-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    final saved = await store.get('e');
    expect(saved!.cells, isEmpty);
  });
}
