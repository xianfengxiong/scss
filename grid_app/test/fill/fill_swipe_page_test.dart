import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/fill/fill_screen.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/model/template.dart';

GridFrame _grid() => GridFrame.uniform(
    xMm: 15, yMm: 10, cols: 12, rows: 16, colWidthMm: 15, rowHeightMm: 8);

TemplatePage _titled(String id, String text) => TemplatePage(
      grid: _grid(),
      cells: [
        Cell(id: id, col: 0, row: 0, colSpan: 12, type: 'title',
            props: {'text': text, 'align': 'center'}),
      ],
    );

void main() {
  Future<void> pump(WidgetTester tester, {int pages = 2}) async {
    await tester.pumpWidget(MaterialApp(
      home: FillScreen(
        template: Template(
          id: 'tpl_1',
          name: 'T',
          page: const PageSize.a4(),
          pages: [
            for (var i = 0; i < pages; i++) _titled('t$i', 'Page ${i + 1}'),
          ],
        ),
        survey: const Survey(id: 'srv_1', templateId: 'tpl_1', name: 'S'),
        store: InMemorySurveyStore(),
        registry: buildDefaultRegistry(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder canvas() => find.byType(InteractiveViewer);

  testWidgets('unzoomed horizontal swipe turns the page both ways',
      (tester) async {
    await pump(tester);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.drag(canvas(), const Offset(-160, 0)); // left → next
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Page 2'), findsOneWidget);

    await tester.drag(canvas(), const Offset(160, 0)); // right → previous
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('a mostly-vertical drag does not turn the page',
      (tester) async {
    await pump(tester);
    await tester.drag(canvas(), const Offset(-70, 120));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('swiping past the last page stays put', (tester) async {
    await pump(tester);
    await tester.drag(canvas(), const Offset(-160, 0));
    await tester.pumpAndSettle();
    await tester.drag(canvas(), const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('zoomed in, a horizontal drag pans instead of turning',
      (tester) async {
    await pump(tester);
    // Double-tap zooms to 1.5×.
    final center = tester.getCenter(canvas());
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();

    await tester.drag(canvas(), const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget, reason: 'pan, not page turn');
  });

  testWidgets('single-page template ignores swipes', (tester) async {
    await pump(tester, pages: 1);
    await tester.drag(canvas(), const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fill-page-indicator')), findsNothing);
  });
}
