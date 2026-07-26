import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/builder/template_list_screen.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/fill/template_surveys_screen.dart';
import 'package:scss_grid/l10n/app_localizations.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  late InMemoryTemplateStore store;
  late InMemorySurveyStore surveyStore;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TemplateListScreen(
          store: store,
          surveyStore: surveyStore,
          registry: buildDefaultRegistry()),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    store = InMemoryTemplateStore();
    surveyStore = InMemorySurveyStore();
    await store.upsert(sampleTemplate().copyWith(id: 'a', name: 'Alpha'));
  });

  testWidgets('lists existing templates and creates a new one via the FAB',
      (tester) async {
    await pump(tester);
    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    // Creating a template navigates into the builder; the new template is in the store.
    expect((await store.all()).length, 2);
  });

  testWidgets('row shows its survey count and opens the surveys screen on tap',
      (tester) async {
    await surveyStore.upsert(Survey(
        id: 's1',
        templateId: 'a',
        name: 'Site One',
        updatedAt: DateTime.parse('2026-07-15T08:00:00')));
    await pump(tester);

    // 从属关系 in the list itself: the row states how many surveys it has.
    expect(find.textContaining('1 survey(s)'), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.byType(TemplateSurveysScreen), findsOneWidget);
    expect(find.text('Site One'), findsOneWidget);
  });

  testWidgets('the design button (not the row) opens the builder',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('design-a')));
    await tester.pumpAndSettle();
    expect(find.byType(BuilderScreen), findsOneWidget);
  });

  testWidgets('delete button asks first and keeps surveys', (tester) async {
    await surveyStore.upsert(Survey(
        id: 's1',
        templateId: 'a',
        name: 'Site One',
        updatedAt: DateTime.parse('2026-07-15T08:00:00')));
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('delete-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await store.get('a'), isNull);
    expect((await surveyStore.all()).length, 1, reason: 'surveys are kept');
  });
}
