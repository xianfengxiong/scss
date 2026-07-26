import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/data/sync_meta_store.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/fill/fill_screen.dart';
import 'package:scss_grid/fill/survey_list_screen.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/sample/sample_template.dart';
import 'package:scss_grid/sync/media_file_store.dart';

/// Phone home mode: survey-first with a FAB that starts a survey from a
/// synced template, plus sync/templates entries in the AppBar.
void main() {
  late InMemorySyncMetaStore meta;
  late InMemoryTemplateStore templates;
  late InMemorySurveyStore surveys;

  setUp(() {
    meta = InMemorySyncMetaStore();
    templates = InMemoryTemplateStore(meta: meta);
    surveys = InMemorySurveyStore(meta: meta);
  });

  Widget home() => MaterialApp(
        home: SurveyListScreen(
          surveyStore: surveys,
          templateStore: templates,
          registry: buildDefaultRegistry(),
          asHome: true,
          meta: meta,
          files: InMemoryMediaFileStore(),
        ),
      );

  testWidgets('home mode shows FAB, sync and templates entries',
      (tester) async {
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('new-survey-fab')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-sync-client')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-templates')), findsOneWidget);
  });

  testWidgets('FAB with no templates explains instead of a dead sheet',
      (tester) async {
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('new-survey-fab')));
    await tester.pumpAndSettle();

    expect(find.textContaining('还没有模版'), findsOneWidget);
  });

  testWidgets('FAB → pick template → name → lands in FillScreen',
      (tester) async {
    final t = sampleTemplate().copyWith(id: 'tpl_1', name: 'Site Survey');
    await templates.upsert(t);
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('new-survey-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick-template-tpl_1')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), 'North Site');
    await tester.tap(find.byKey(const ValueKey('survey-name-ok')));
    await tester.pumpAndSettle();

    expect(find.byType(FillScreen), findsOneWidget);
    expect((await surveys.all()).single.name, 'North Site');
    expect((await surveys.all()).single.templateId, 'tpl_1');
  });

  testWidgets('non-home mode keeps the plain list (no FAB, no entries)',
      (tester) async {
    await surveys.upsert(
        const Survey(id: 'srv_1', templateId: 'tpl_1', name: 'S'));
    await tester.pumpWidget(MaterialApp(
      home: SurveyListScreen(
        surveyStore: surveys,
        templateStore: templates,
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('new-survey-fab')), findsNothing);
    expect(find.byKey(const ValueKey('open-sync-client')), findsNothing);
    expect(find.byKey(const ValueKey('open-templates')), findsNothing);
  });

  testWidgets('desktop shows a visible delete button that asks first',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await surveys.upsert(
        const Survey(id: 'srv_1', templateId: 'tpl_1', name: 'ToDelete'));
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-srv_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await surveys.get('srv_1'), isNull);
    expect((await meta.tombstones()).single.id, 'srv_1');
    debugDefaultTargetPlatformOverride = null;
  });
}
