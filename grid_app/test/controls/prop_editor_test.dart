import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/controls/title_control.dart';
import 'package:scss_grid/controls/label_control.dart';

void main() {
  testWidgets('TitleControl.propEditor edits the text prop', (tester) async {
    Map<String, dynamic>? out;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TitleControl().propEditor(
            const Cell(id: 't', col: 0, row: 0, type: 'title',
                props: {'text': 'Old'}),
            (p) => out = p),
      ),
    ));
    await tester.enterText(find.byType(TextFormField), 'New title');
    expect(out!['text'], 'New title');
  });

  testWidgets('LabelControl.propEditor edits the text prop', (tester) async {
    Map<String, dynamic>? out;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LabelControl().propEditor(
            const Cell(id: 'l', col: 0, row: 0, type: 'label',
                props: {'text': 'Old', 'align': 'left', 'bold': false}),
            (p) => out = p),
      ),
    ));
    await tester.enterText(find.byType(TextFormField).first, 'Site Name');
    expect(out!['text'], 'Site Name');
  });
}
