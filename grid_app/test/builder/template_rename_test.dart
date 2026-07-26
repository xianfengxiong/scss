import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/builder/template_list_screen.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/l10n/app_localizations.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  late InMemoryTemplateStore templates;
  late InMemorySurveyStore surveys;

  setUp(() async {
    templates = InMemoryTemplateStore();
    surveys = InMemorySurveyStore();
    await templates
        .upsert(sampleTemplate().copyWith(id: 'tpl_1', name: 'Old Name'));
  });

  testWidgets('list rename persists the new name and stamps updatedAt',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TemplateListScreen(
        store: templates,
        surveyStore: surveys,
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rename-tpl_1')));
    await tester.pumpAndSettle();
    expect(find.text('Rename template'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), 'Site Survey v2');
    await tester.tap(find.byKey(const ValueKey('survey-name-ok')));
    await tester.pumpAndSettle();

    final t = await templates.get('tpl_1');
    expect(t?.name, 'Site Survey v2');
    expect(t?.updatedAt, isNotNull, reason: 'sync needs the LWW stamp');
    expect(find.text('Site Survey v2'), findsOneWidget);
  });

  testWidgets('list rename cancel changes nothing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TemplateListScreen(
        store: templates,
        surveyStore: surveys,
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rename-tpl_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect((await templates.get('tpl_1'))?.name, 'Old Name');
  });

  testWidgets('builder rename updates the AppBar title and persists at once',
      (tester) async {
    final t = await templates.get('tpl_1');
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BuilderScreen(
        template: t!,
        registry: buildDefaultRegistry(),
        store: templates,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('builder-rename')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), 'Renamed In Builder');
    await tester.tap(find.byKey(const ValueKey('survey-name-ok')));
    await tester.pumpAndSettle();

    expect(find.text('Renamed In Builder'), findsOneWidget);
    // Persisted without pressing Save.
    final saved = await templates.get('tpl_1');
    expect(saved?.name, 'Renamed In Builder');
    expect(saved?.updatedAt, isNotNull);
  });
}
