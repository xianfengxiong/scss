import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/sample/sample_template.dart';

/// Desktop builder layout: palette docked left, properties docked right,
/// both collapsible. The phone keeps the stacked layout (covered by the
/// existing builder tests, which run on the default test platform).
void main() {
  // The platform override must be reset inside the test body — the
  // framework's invariant check runs before tearDown callbacks.
  Future<void> onDesktop(
      WidgetTester tester, Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(MaterialApp(
        home: BuilderScreen(
          template: sampleTemplate().copyWith(id: 'tpl_1'),
          registry: buildDefaultRegistry(),
          store: InMemoryTemplateStore(),
        ),
      ));
      await tester.pumpAndSettle();
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    }
  }

  testWidgets('shows both docks with the palette vertical on the left',
      (tester) async {
    await onDesktop(tester, () async {
      expect(find.text('Controls'), findsOneWidget);
      expect(find.text('Properties'), findsOneWidget);
      // Palette tiles are present as full-width rows (vertical axis).
      expect(find.text('Image'), findsOneWidget);
      expect(find.text('点击画布上的控件以编辑属性'), findsOneWidget);
    });
  });

  testWidgets('selecting a cell shows its editor in the right dock, no chevron',
      (tester) async {
    await onDesktop(tester, () async {
      // Adding from the palette auto-selects the new cell.
      await tester.tap(find.text('Title').first);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cell-delete')), findsOneWidget);
      expect(find.byKey(const ValueKey('colspan-inc')), findsOneWidget);
      // Docked mode has no collapse chevron of its own.
      expect(find.byKey(const ValueKey('inspector-toggle')), findsNothing);
    });
  });

  testWidgets('docks collapse to a rail and expand back', (tester) async {
    await onDesktop(tester, () async {
      await tester.tap(find.byKey(const ValueKey('dock-toggle-Controls')));
      await tester.pumpAndSettle();
      expect(find.text('Image'), findsNothing, reason: 'palette collapsed');
      expect(find.text('Controls'), findsOneWidget,
          reason: 'rail keeps title');

      await tester.tap(find.byKey(const ValueKey('dock-toggle-Controls')));
      await tester.pumpAndSettle();
      expect(find.text('Image'), findsOneWidget, reason: 'palette back');

      await tester.tap(find.byKey(const ValueKey('dock-toggle-Properties')));
      await tester.pumpAndSettle();
      expect(find.text('点击画布上的控件以编辑属性'), findsNothing);
    });
  });

  testWidgets('vertical palette tap-to-add still works', (tester) async {
    await onDesktop(tester, () async {
      await tester.tap(find.text('Label').first);
      await tester.pumpAndSettle();
      // The new cell is auto-selected → its editor appears in the right dock.
      expect(find.byKey(const ValueKey('cell-delete')), findsOneWidget);
    });
  });
}
