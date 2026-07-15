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

class _CountingStore extends InMemorySurveyStore {
  int upserts = 0;
  @override
  Future<void> upsert(Survey s) {
    upserts++;
    return super.upsert(s);
  }
}

void main() {
  testWidgets('autosaves after a 500ms debounce; rapid edits merge into one write',
      (tester) async {
    final store = _CountingStore();
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
    expect(find.byTooltip('Save'), findsNothing); // Save 按钮已移除

    await tester.enterText(find.byType(TextFormField), 'Gj');
    await tester.pump(const Duration(milliseconds: 200)); // 防抖窗口内
    await tester.enterText(find.byType(TextFormField), 'Gjirokaster');
    expect(store.upserts, 0); // 还没到 500ms,一次都没写

    await tester.pump(const Duration(milliseconds: 600));
    expect(store.upserts, 1); // 两次输入合并为一次写

    final saved = await store.get('s1');
    expect(saved!.data['site_name'], 'Gjirokaster');
    expect(saved.updatedAt, isNotNull);
  });

  testWidgets('pending edit is flushed when the screen is disposed',
      (tester) async {
    final store = _CountingStore();
    const survey = Survey(id: 's1', templateId: 't1', name: 'Site Survey');
    await tester.pumpWidget(MaterialApp(
      home: FillScreen(
        template: _tpl(),
        survey: survey,
        store: store,
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.enterText(find.byType(TextFormField), 'Berat');
    // 防抖未到期就销毁页面(等价于用户立刻按返回)
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    expect(store.upserts, 1);
    expect((await store.get('s1'))!.data['site_name'], 'Berat');
  });

  testWidgets('fill canvas is wrapped in a zoomable InteractiveViewer; '
      'keyboard does not resize the page', (tester) async {
    final store = InMemorySurveyStore();
    final survey = Survey(id: 's1', templateId: 't1', name: 'S1');
    await tester.pumpWidget(MaterialApp(
      home: FillScreen(
        template: _tpl(),
        survey: survey,
        store: store,
        registry: buildDefaultRegistry(),
      ),
    ));
    expect(find.byType(InteractiveViewer), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.resizeToAvoidBottomInset, isFalse);
  });
}
