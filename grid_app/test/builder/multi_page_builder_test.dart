import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/builder/editor_ops.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  group('page ops', () {
    test('addPageAfter inherits the grid but no controls', () {
      final t = sampleTemplate().copyWith(id: 't');
      final added = addPageAfter(t, 0);
      expect(added.pages.length, 2);
      expect(added.pages[1].grid.cols, t.pages[0].grid.cols);
      expect(added.pages[1].grid.rowHeightsMm, t.pages[0].grid.rowHeightsMm);
      expect(added.pages[1].cells, isEmpty);
      expect(added.pages[0].cells, t.pages[0].cells);
    });

    test('removePage refuses to delete the last page', () {
      final t = sampleTemplate().copyWith(id: 't');
      expect(removePage(t, 0), isNull);
      final two = addPageAfter(t, 0);
      expect(removePage(two, 1)!.pages.length, 1);
    });

    test('uniqueKey looks across all pages', () {
      var t = sampleTemplate().copyWith(id: 't'); // page 0 uses site_name
      t = addPageAfter(t, 0);
      expect(uniqueKey(t, 'site_name'), 'site_name_1');
    });
  });

  group('builder page navigation', () {
    late InMemoryTemplateStore store;

    Future<void> pump(WidgetTester tester) async {
      store = InMemoryTemplateStore();
      final t = sampleTemplate().copyWith(id: 'tpl_1');
      await store.upsert(t);
      await tester.pumpWidget(MaterialApp(
        home: BuilderScreen(
            template: t,
            registry: buildDefaultRegistry(),
            store: store),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('add page → indicator 2/2, canvas shows the empty new page',
        (tester) async {
      await pump(tester);
      expect(find.text('1/1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('page-add')));
      await tester.pumpAndSettle();

      expect(find.text('2/2'), findsOneWidget);
      // The sample title lives on page 1; page 2 is empty.
      expect(find.text('Site Survey Form'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('page-prev')));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Site Survey Form'), findsOneWidget);
    });

    testWidgets('delete page on the only page is disabled', (tester) async {
      await pump(tester);
      final btn = tester
          .widget<IconButton>(find.byKey(const ValueKey('page-delete')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('deleting an empty page needs no confirmation and saves',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('page-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('page-delete')));
      await tester.pumpAndSettle();
      expect(find.text('1/1'), findsOneWidget);

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect((await store.get('tpl_1'))!.pages.length, 1);
    });

    testWidgets('deleting a page with controls asks first', (tester) async {
      await pump(tester);
      // Page 1 (the sample page) has controls; deleting it must confirm.
      await tester.tap(find.byKey(const ValueKey('page-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('page-prev')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('page-delete')));
      await tester.pumpAndSettle();
      expect(find.textContaining('删除第 1 页'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('1/1'), findsOneWidget);
      expect(find.text('Site Survey Form'), findsNothing,
          reason: 'the designed page is gone; the empty one remains');
    });

    testWidgets('multi-page template saves and reloads with all pages',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('page-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      final saved = await store.get('tpl_1');
      expect(saved!.pages.length, 2);
      final reread = Template.fromJson(saved.toJson());
      expect(reread.pages.length, 2);
    });
  });
}
