import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/template_list_screen.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/fill/fill_screen.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  testWidgets('lists existing templates and creates a new one via the FAB',
      (tester) async {
    final store = InMemoryTemplateStore();
    await store.upsert(sampleTemplate().copyWith(id: 'a', name: 'Alpha'));

    await tester.pumpWidget(MaterialApp(
      home: TemplateListScreen(
          store: store,
          surveyStore: InMemorySurveyStore(),
          registry: buildDefaultRegistry()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    // Creating a template navigates into the builder; the new template is in the store.
    expect((await store.all()).length, 2);
  });

  testWidgets('Fill with no surveys goes straight to the name dialog; '
      'OK persists and opens FillScreen', (tester) async {
    final store = InMemoryTemplateStore();
    await store.upsert(sampleTemplate().copyWith(id: 'a', name: 'Alpha'));
    final surveyStore = InMemorySurveyStore();

    await tester.pumpWidget(MaterialApp(
      home: TemplateListScreen(
          store: store,
          surveyStore: surveyStore,
          registry: buildDefaultRegistry()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fill-a')));
    await tester.pumpAndSettle();
    // 无既有 survey → 跳过 sheet,直接命名框(预填 'Alpha yyyy-MM-dd')
    expect(find.byKey(const ValueKey('survey-name-field')), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), 'Site One');
    await tester.tap(find.byKey(const ValueKey('survey-name-ok')));
    await tester.pumpAndSettle();

    expect(find.byType(FillScreen), findsOneWidget);
    final saved = await surveyStore.all(); // 新建即落库
    expect(saved.length, 1);
    expect(saved.single.name, 'Site One');
    expect(saved.single.templateId, 'a');
    expect(saved.single.updatedAt, isNotNull);
  });

  testWidgets('Fill with existing surveys shows a sheet; tapping one resumes it',
      (tester) async {
    final store = InMemoryTemplateStore();
    await store.upsert(sampleTemplate().copyWith(id: 'a', name: 'Alpha'));
    final surveyStore = InMemorySurveyStore();
    await surveyStore.upsert(Survey(
        id: 's1',
        templateId: 'a',
        name: 'Site One',
        updatedAt: DateTime.parse('2026-07-15T08:00:00')));

    await tester.pumpWidget(MaterialApp(
      home: TemplateListScreen(
          store: store,
          surveyStore: surveyStore,
          registry: buildDefaultRegistry()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fill-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fill-new')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fill-resume-s1')));
    await tester.pumpAndSettle();
    expect(find.byType(FillScreen), findsOneWidget);
    expect(find.text('Site One'), findsOneWidget); // FillScreen 标题=survey 名
    expect((await surveyStore.all()).length, 1); // 续填不新建
  });

  testWidgets('sheet New survey item opens the name dialog', (tester) async {
    final store = InMemoryTemplateStore();
    await store.upsert(sampleTemplate().copyWith(id: 'a', name: 'Alpha'));
    final surveyStore = InMemorySurveyStore();
    await surveyStore.upsert(Survey(
        id: 's1',
        templateId: 'a',
        name: 'Site One',
        updatedAt: DateTime.parse('2026-07-15T08:00:00')));

    await tester.pumpWidget(MaterialApp(
      home: TemplateListScreen(
          store: store,
          surveyStore: surveyStore,
          registry: buildDefaultRegistry()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fill-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fill-new')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('survey-name-field')), findsOneWidget);
  });
}
