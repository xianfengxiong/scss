import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/builder_screen.dart';
import 'package:scss_grid/builder/grid_canvas.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  testWidgets('BuilderScreen shows the template name and its canvas, and Save persists',
      (tester) async {
    final store = InMemoryTemplateStore();
    final t = sampleTemplate();
    await tester.pumpWidget(MaterialApp(
      home: BuilderScreen(
          template: t, registry: buildDefaultRegistry(), store: store),
    ));
    expect(find.text(t.name), findsOneWidget); // app bar title
    expect(find.byType(GridCanvas), findsOneWidget);

    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    expect((await store.get(t.id))!.id, t.id); // saved
  });
}
