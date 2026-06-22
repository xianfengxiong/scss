import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/fill/fill_canvas.dart';
import 'package:scss_grid/fill/fill_screen.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/model/template.dart';

Template _tpl() => Template(
      id: 't1',
      name: 'Site Survey',
      page: const PageSize.a4(),
      grid: GridFrame.uniform(
          xMm: 0, yMm: 0, cols: 12, rows: 4, colWidthMm: 15, rowHeightMm: 20),
      cells: const [
        Cell(id: 'name_l', col: 0, row: 0, colSpan: 3, type: 'label',
            props: {'text': 'Site', 'align': 'left', 'bold': false}),
        Cell(id: 'name_v', col: 3, row: 0, colSpan: 9, type: 'text',
            props: {'key': 'site_name', 'hint': ''}),
      ],
    );

void main() {
  testWidgets('renders the fill canvas and Save persists entered values',
      (tester) async {
    final store = InMemorySurveyStore();
    const survey = Survey(id: 's1', templateId: 't1', name: 'Site Survey');
    await tester.pumpWidget(MaterialApp(
      home: FillScreen(
        template: _tpl(),
        survey: survey,
        store: store,
        registry: buildDefaultRegistry(),
      ),
    ));
    expect(find.byType(FillCanvas), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Gjirokaster');
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    final saved = await store.get('s1');
    expect(saved!.data['site_name'], 'Gjirokaster');
  });
}
