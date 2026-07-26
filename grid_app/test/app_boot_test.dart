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
  // Both ends share one hierarchy (templates → surveys → fill); only the
  // sync entry behaves differently (host vs client).
  testWidgets('phone boots to the template list with a sync entry',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('SCSS Templates'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-sync')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop boots to the template list with a sync entry',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('SCSS Templates'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-sync')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
