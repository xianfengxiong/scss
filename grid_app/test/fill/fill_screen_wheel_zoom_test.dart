import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/survey_store.dart';
import 'package:scss_grid/fill/fill_screen.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/sample/sample_template.dart';

/// Desktop fill screen: Ctrl/Cmd + mouse wheel zooms at the pointer; a bare
/// wheel never zooms (it pans when zoomed in). Phone pinch (IV scaling) is
/// untouched — these tests run with the desktop platform override.
void main() {
  Future<void> onDesktop(
      WidgetTester tester, Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(MaterialApp(
        home: FillScreen(
          template: sampleTemplate().copyWith(id: 'tpl_1'),
          survey: const Survey(id: 'srv_1', templateId: 'tpl_1', name: 'S'),
          store: InMemorySurveyStore(),
          registry: buildDefaultRegistry(),
        ),
      ));
      await tester.pumpAndSettle();
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    }
  }

  double scaleOf(WidgetTester tester) => tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!
      .value
      .getMaxScaleOnAxis();

  Future<void> wheel(WidgetTester tester, double dy) async {
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(find.byType(InteractiveViewer)));
    await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
    await tester.pump();
  }

  testWidgets('Ctrl+wheel-up zooms in, Ctrl+wheel-down zooms back out',
      (tester) async {
    await onDesktop(tester, () async {
      expect(scaleOf(tester), 1.0);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await wheel(tester, -200); // wheel up → zoom in
      expect(scaleOf(tester), greaterThan(1.0));

      await wheel(tester, 400); // wheel down well past the start → clamp at 1×
      expect(scaleOf(tester), 1.0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    });
  });

  testWidgets('a bare mouse wheel never zooms', (tester) async {
    await onDesktop(tester, () async {
      await wheel(tester, -200);
      expect(scaleOf(tester), 1.0);
    });
  });

  testWidgets('zoom clamps at the max scale', (tester) async {
    await onDesktop(tester, () async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      for (var i = 0; i < 30; i++) {
        await wheel(tester, -400);
      }
      expect(scaleOf(tester), 4.0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    });
  });
}
