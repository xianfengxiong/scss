import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/cell_inspector.dart';
import 'package:scss_grid/controls/field_control.dart';
import 'package:scss_grid/model/cell.dart';

// Host that can swap which cell the inspector shows, to mimic selecting a
// different control on the canvas.
class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Cell _cell = const Cell(id: 'a', col: 0, row: 0, colSpan: 12, type: 'field',
      props: {'label': 'Site Name', 'key': 'site_name', 'valueType': 'text'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextButton(
              onPressed: () => setState(() {
                _cell = const Cell(id: 'b', col: 0, row: 1, colSpan: 12,
                    type: 'field',
                    props: {'label': 'Site City', 'key': 'site_city',
                        'valueType': 'text'});
              }),
              child: const Text('select-b'),
            ),
            CellInspector(
              cell: _cell,
              spec: FieldControl(),
              maxColSpan: 12,
              onPropsChanged: (_) {},
              onColSpanChanged: (_) {},
              onDelete: () {},
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('property editor shows the newly selected cell\'s label',
      (tester) async {
    await tester.pumpWidget(const _Host());
    // Inspector shows cell A's label in the editable field.
    expect(find.widgetWithText(TextFormField, 'Site Name'), findsOneWidget);

    // Select cell B.
    await tester.tap(find.text('select-b'));
    await tester.pumpAndSettle();

    // The editor must now show B's label, not A's stale text.
    expect(find.widgetWithText(TextFormField, 'Site City'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Site Name'), findsNothing);
  });
}
