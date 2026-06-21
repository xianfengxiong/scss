import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/main.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/data/template_store.dart';

void main() {
  testWidgets('app boots to the template list', (tester) async {
    await tester.pumpWidget(ScssGridApp(
        store: InMemoryTemplateStore(), registry: buildDefaultRegistry()));
    await tester.pumpAndSettle();
    expect(find.text('SCSS Templates'), findsOneWidget);
  });
}
