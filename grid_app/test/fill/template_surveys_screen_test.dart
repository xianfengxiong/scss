import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/fill/fill_screen.dart';
import 'package:scss_grid/fill/template_surveys_screen.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  late InMemorySurveyStore store;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TemplateSurveysScreen(
        template: sampleTemplate().copyWith(id: 'a', name: 'Alpha'),
        surveyStore: store,
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() => store = InMemorySurveyStore());

  Future<void> seed() => store.upsert(Survey(
      id: 's1',
      templateId: 'a',
      name: 'Site One',
      updatedAt: DateTime.parse('2026-07-15T08:00:00')));

  testWidgets('empty state invites creating the first survey', (tester) async {
    await pump(tester);
    expect(find.textContaining('还没有调查表'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-survey')), findsOneWidget);
  });

  testWidgets('new survey: name dialog → persisted → FillScreen',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('new-survey')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), 'North Site');
    await tester.tap(find.byKey(const ValueKey('survey-name-ok')));
    await tester.pumpAndSettle();

    expect(find.byType(FillScreen), findsOneWidget);
    final saved = (await store.all()).single;
    expect(saved.name, 'North Site');
    expect(saved.templateId, 'a');
  });

  testWidgets('tapping a survey resumes it (no new row)', (tester) async {
    await seed();
    await pump(tester);
    expect(find.textContaining('1 份调查表'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('survey-s1')));
    await tester.pumpAndSettle();
    expect(find.byType(FillScreen), findsOneWidget);
    expect((await store.all()).length, 1);
  });

  testWidgets('rename updates the row', (tester) async {
    await seed();
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('rename-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), 'Renamed');
    await tester.tap(find.byKey(const ValueKey('survey-name-ok')));
    await tester.pumpAndSettle();

    expect(find.text('Renamed'), findsOneWidget);
    expect((await store.get('s1'))?.name, 'Renamed');
  });

  testWidgets('delete asks first', (tester) async {
    await seed();
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('delete-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await store.get('s1'), isNull);
    expect(find.textContaining('还没有调查表'), findsOneWidget);
  });
}
