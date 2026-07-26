import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/main.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/sync_meta_store.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/sync/media_file_store.dart';

ScssGridApp app() => ScssGridApp(
      store: InMemoryTemplateStore(),
      surveyStore: InMemorySurveyStore(),
      meta: InMemorySyncMetaStore(),
      files: InMemoryMediaFileStore(),
      registry: buildDefaultRegistry(),
    );

void main() {
  testWidgets('app boots to the survey list on phones (fill-first)',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('SCSS Surveys'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('app boots to the template list on desktop (design-first)',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('SCSS Templates'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
