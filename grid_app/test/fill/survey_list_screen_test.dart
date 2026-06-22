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
    expect(await surveyStore.all(), isEmpty);
  });
}
