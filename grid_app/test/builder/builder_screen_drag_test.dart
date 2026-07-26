import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/builder/editable_canvas.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/l10n/app_localizations.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';

Template _one() => Template(
      id: 'o',
      name: 'One',
      page: const PageSize.a4(),
      pages: [
        TemplatePage(
          grid: GridFrame.uniform(
              xMm: 0, yMm: 0, cols: 6, rows: 6,
              colWidthMm: 30, rowHeightMm: 30),
          cells: const [
            Cell(id: 'a', col: 0, row: 0, colSpan: 1, type: 'text',
                props: {'key': 'k', 'hint': ''}),
          ],
        ),
      ],
    );

void main() {
  testWidgets('the builder uses an EditableCanvas', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BuilderScreen(
          template: _one(),
          registry: buildDefaultRegistry(),
          store: InMemoryTemplateStore()),
    ));
    expect(find.byType(EditableCanvas), findsOneWidget);
  });
}
