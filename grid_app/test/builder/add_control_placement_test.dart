import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/l10n/app_localizations.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

// A template with row 0 half-occupied (cols 0..5 by a text cell), so a newly
// added control should land at (6,0) spanning the remaining 6 columns — NOT
// on row 1.
Template _partial() => Template(
      id: 'p',
      name: 'Partial',
      page: const PageSize.a4(),
      pages: [
        TemplatePage(
          grid: GridFrame.uniform(
              xMm: 10, yMm: 10, cols: 12, rows: 16,
              colWidthMm: 15, rowHeightMm: 8),
          cells: const [
            Cell(id: 'a', col: 0, row: 0, colSpan: 6, type: 'text',
                props: {'key': 'k', 'hint': ''}),
          ],
        ),
      ],
    );

void main() {
  testWidgets('tapping a palette control fills the first free cell on the row',
      (tester) async {
    final store = InMemoryTemplateStore();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BuilderScreen(
          template: _partial(),
          registry: buildDefaultRegistry(),
          store: store),
    ));
    await tester.tap(find.text('Text')); // palette item
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await tester.pump();

    final saved = await store.get('p');
    expect(saved!.pages[0].cells.length, 2);
    final added = saved.pages[0].cells.firstWhere((c) => c.id != 'a');
    expect([added.col, added.row, added.colSpan], [6, 0, 6]);
  });
}
