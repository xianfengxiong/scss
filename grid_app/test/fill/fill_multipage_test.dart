import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/fill/fill_screen.dart';
import 'package:scss_grid/l10n/app_localizations.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/model/template.dart';

GridFrame _grid() => GridFrame.uniform(
    xMm: 15, yMm: 10, cols: 12, rows: 16, colWidthMm: 15, rowHeightMm: 8);

Template _twoPages() => Template(
      id: 'tpl_1',
      name: 'T',
      page: const PageSize.a4(),
      pages: [
        TemplatePage(grid: _grid(), cells: const [
          Cell(id: 'p1', col: 0, row: 0, colSpan: 12, type: 'title',
              props: {'text': 'Page One Title', 'align': 'center'}),
          Cell(id: 'f1', col: 0, row: 1, colSpan: 12, type: 'text',
              props: {'key': 'field1', 'hint': ''}),
        ]),
        TemplatePage(grid: _grid(), cells: const [
          Cell(id: 'p2', col: 0, row: 0, colSpan: 12, type: 'title',
              props: {'text': 'Page Two Title', 'align': 'center'}),
          Cell(id: 'f2', col: 0, row: 1, colSpan: 12, type: 'text',
              props: {'key': 'field2', 'hint': ''}),
        ]),
      ],
    );

void main() {
  Future<InMemorySurveyStore> pump(WidgetTester tester) async {
    final store = InMemorySurveyStore();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FillScreen(
        template: _twoPages(),
        survey: const Survey(id: 'srv_1', templateId: 'tpl_1', name: 'S'),
        store: store,
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('page bar switches pages; single map holds both pages\' data',
      (tester) async {
    final store = await pump(tester);

    expect(find.text('Page One Title'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'answer one');

    await tester.tap(find.byKey(const ValueKey('fill-page-next')));
    await tester.pumpAndSettle();
    expect(find.text('Page Two Title'), findsOneWidget);
    expect(find.text('Page One Title'), findsNothing);
    await tester.enterText(find.byType(TextFormField), 'answer two');

    // Flush the debounced autosave, then check one shared answers map.
    await tester.pump(const Duration(seconds: 1));
    final saved = await store.get('srv_1');
    expect(saved!.data['field1'], 'answer one');
    expect(saved.data['field2'], 'answer two');
  });

  testWidgets('single-page template shows no page bar', (tester) async {
    final one = _twoPages();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FillScreen(
        template: one.copyWith(pages: [one.pages.first]),
        survey: const Survey(id: 'srv_1', templateId: 'tpl_1', name: 'S'),
        store: InMemorySurveyStore(),
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fill-page-indicator')), findsNothing);
  });
}
