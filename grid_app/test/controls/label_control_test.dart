import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/label_control.dart';
import 'package:scss_grid/model/cell.dart';

const _cell = Cell(id: 'l', col: 0, row: 0, colSpan: 3, type: 'label',
    props: {'text': 'Site Name', 'align': 'left', 'bold': true});

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 200, height: 300, child: child)));

void main() {
  test('type, defaultProps, and dataKey (no data key for a label)', () {
    final c = LabelControl();
    expect(c.type, 'label');
    expect(c.defaultProps(), {'text': 'Label', 'align': 'left', 'bold': false});
    expect(c.dataKey(_cell), isNull);
  });

  testWidgets('previewWidget shows the text', (tester) async {
    await tester.pumpWidget(_host(LabelControl().previewWidget(_cell)));
    expect(find.text('Site Name'), findsOneWidget);
  });

  testWidgets('fillWidget is read-only (shows text, no input)', (tester) async {
    await tester.pumpWidget(_host(LabelControl().fillWidget(_cell, null, (_) {})));
    expect(find.text('Site Name'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('propEditor edits text, align, and bold', (tester) async {
    var props = <String, dynamic>{...const {'text': 'Site Name', 'align': 'left', 'bold': false}};
    await tester.pumpWidget(_host(
      LabelControl().propEditor(_cell, (p) => props = p),
    ));
    await tester.enterText(find.byType(TextFormField), 'City');
    expect(props['text'], 'City');
  });
}
