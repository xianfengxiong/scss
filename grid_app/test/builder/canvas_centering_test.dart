import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/builder/editor_ops.dart';
import 'package:scss_grid/builder/grid_canvas.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/l10n/app_localizations.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  test('centerGridX derives xMm from the column total', () {
    // 12 * 15 = 180mm on a 210mm page → x = 15 regardless of the stored x.
    final t = sampleTemplate();
    final offCenter =
        t.pages[0].copyWith(grid: t.pages[0].grid.copyWith(xMm: 10.0));
    expect(centerGridX(offCenter, t.page).grid.xMm, 15.0);
    // Already centered → unchanged instance data.
    expect(centerGridX(centerGridX(offCenter, t.page), t.page).grid.xMm, 15.0);
  });

  test('centerGridX leaves an over-wide frame alone for the guards to reject',
      () {
    final t = sampleTemplate();
    final tooWide = t.pages[0].copyWith(
      grid: GridFrame.uniform(
          xMm: 0, yMm: 10, cols: 12, rows: 16, colWidthMm: 20, rowHeightMm: 8),
    );
    expect(centerGridX(tooWide, t.page).grid.xMm, 0.0);
  });

  testWidgets('opening an off-center legacy template saves it centered',
      (tester) async {
    final store = InMemoryTemplateStore();
    final base = sampleTemplate();
    final legacy = base.copyWith(
        id: 'tpl_1',
        pages: [
          base.pages[0].copyWith(grid: base.pages[0].grid.copyWith(xMm: 10.0))
        ]);
    await store.upsert(legacy);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BuilderScreen(
          template: legacy,
          registry: buildDefaultRegistry(),
          store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect((await store.get('tpl_1'))?.pages[0].grid.xMm, 15.0);
  });

  testWidgets('canvas page centers horizontally in a wide (desktop) window',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BuilderScreen(
        template: sampleTemplate().copyWith(id: 'tpl_1'),
        registry: buildDefaultRegistry(),
        store: InMemoryTemplateStore(),
      ),
    ));
    await tester.pumpAndSettle();

    final page = tester.getRect(find.byType(GridCanvas));
    final leftGap = page.left;
    final rightGap = 1200.0 - page.right;
    expect((leftGap - rightGap).abs(), lessThan(1.0),
        reason: 'left gap $leftGap vs right gap $rightGap — page must center');
  });
}
