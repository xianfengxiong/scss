import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/fill/fill_screen.dart';
import 'package:scss_grid/fill/survey_list_screen.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  testWidgets('lists surveys; tapping one resumes it in FillScreen',
      (tester) async {
    final templateStore = InMemoryTemplateStore();
    await templateStore.upsert(sampleTemplate()); // id 'sample'
    final surveyStore = InMemorySurveyStore();
    await surveyStore.upsert(const Survey(
        id: 's1', templateId: 'sample', name: 'Castle survey',
        data: {'site_name': 'Gjirokaster'}));

    await tester.pumpWidget(MaterialApp(
      home: SurveyListScreen(
        surveyStore: surveyStore,
        templateStore: templateStore,
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Castle survey'), findsOneWidget);

    await tester.tap(find.text('Castle survey'));
    await tester.pumpAndSettle();
    expect(find.byType(FillScreen), findsOneWidget);
  });

  testWidgets('swipe deletes a survey', (tester) async {
    final surveyStore = InMemorySurveyStore();
    await surveyStore.upsert(
        const Survey(id: 's1', templateId: 'sample', name: 'Castle survey'));

    await tester.pumpWidget(MaterialApp(
      home: SurveyListScreen(
        surveyStore: surveyStore,
        templateStore: InMemoryTemplateStore(),
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Castle survey'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    // Swipe now asks first (same confirmation as the buttons).
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await surveyStore.all(), isEmpty);
  });

  testWidgets('newest first; subtitle shows template name and relative time',
      (tester) async {
    final templateStore = InMemoryTemplateStore();
    await templateStore.upsert(sampleTemplate()); // id 'sample'
    final surveyStore = InMemorySurveyStore();
    await surveyStore.upsert(Survey(
        id: 'old', templateId: 'sample', name: 'Old site',
        updatedAt: DateTime.now().subtract(const Duration(days: 2))));
    await surveyStore.upsert(Survey(
        id: 'new', templateId: 'sample', name: 'New site',
        updatedAt: DateTime.now()));

    await tester.pumpWidget(MaterialApp(
      home: SurveyListScreen(
        surveyStore: surveyStore,
        templateStore: templateStore,
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();

    final newY = tester.getTopLeft(find.text('New site')).dy;
    final oldY = tester.getTopLeft(find.text('Old site')).dy;
    expect(newY, lessThan(oldY)); // 最近更新在前

    // subtitle 含模板名(sampleTemplate 的 name)与相对时间
    expect(find.textContaining(sampleTemplate().name), findsNWidgets(2));
    expect(find.textContaining('2d ago'), findsOneWidget);
  });

  testWidgets('rename button opens dialog; OK persists new name',
      (tester) async {
    final surveyStore = InMemorySurveyStore();
    await surveyStore.upsert(Survey(
        id: 's1', templateId: 'sample', name: 'Old name',
        updatedAt: DateTime.now()));

    await tester.pumpWidget(MaterialApp(
      home: SurveyListScreen(
        surveyStore: surveyStore,
        templateStore: InMemoryTemplateStore(),
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rename-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), 'New name');
    await tester.tap(find.byKey(const ValueKey('survey-name-ok')));
    await tester.pumpAndSettle();

    expect(find.text('New name'), findsOneWidget);
    expect((await surveyStore.get('s1'))!.name, 'New name');
  });

  testWidgets(
      'rename re-reads the latest row so it does not clobber a just-flushed '
      'autosave edit (F2)', (tester) async {
    final surveyStore = InMemorySurveyStore();
    await surveyStore.upsert(Survey(
        id: 's1', templateId: 'sample', name: 'A',
        data: const {'k': 'old'}, updatedAt: DateTime.now()));

    await tester.pumpWidget(MaterialApp(
      home: SurveyListScreen(
        surveyStore: surveyStore,
        templateStore: InMemoryTemplateStore(),
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle(); // list 快照了旧的 s1(data: old)

    // 模拟 FillScreen 在列表快照之后才落地的一次 autosave flush:直接写
    // store,不刷新这个已挂载的列表 widget。
    await surveyStore.upsert(Survey(
        id: 's1', templateId: 'sample', name: 'A',
        data: const {'k': 'new'}, updatedAt: DateTime.now()));

    await tester.tap(find.byKey(const ValueKey('rename-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), 'B');
    await tester.tap(find.byKey(const ValueKey('survey-name-ok')));
    await tester.pumpAndSettle();

    final saved = await surveyStore.get('s1');
    expect(saved!.name, 'B');
    expect(saved.data['k'], 'new'); // 没有被 stale 的列表快照冲回 'old'
  });
}
