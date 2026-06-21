import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/template_list_screen.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  testWidgets('lists existing templates and creates a new one via the FAB',
      (tester) async {
    final store = InMemoryTemplateStore();
    await store.upsert(sampleTemplate().copyWith(id: 'a', name: 'Alpha'));

    await tester.pumpWidget(MaterialApp(
      home: TemplateListScreen(store: store, registry: buildDefaultRegistry()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    // Creating a template navigates into the builder; the new template is in the store.
    expect((await store.all()).length, 2);
  });
}
