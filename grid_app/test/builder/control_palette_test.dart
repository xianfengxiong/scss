import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/control_palette.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/controls/control_spec.dart';

void main() {
  testWidgets('palette lists controls and reports the picked one',
      (tester) async {
    ControlSpec? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ControlPalette(
            registry: buildDefaultRegistry(), onPick: (s) => picked = s),
      ),
    ));
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    await tester.tap(find.text('Text'));
    expect(picked!.type, 'text');
  });
}
