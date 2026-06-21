import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/grid_canvas.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  testWidgets('GridCanvas renders title and field text from the template',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: GridCanvas(
                template: sampleTemplate(), registry: buildDefaultRegistry()),
          ),
        ),
      ),
    ));
    expect(find.text('Site Survey Form'), findsOneWidget);
    expect(find.text('Site Name'), findsOneWidget);
    expect(find.text('Site City'), findsOneWidget);
  });

  testWidgets('GridCanvas preserves A4 aspect ratio for its given width',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 210, // 1mm == 1px at this width → height should be ~297
            child: GridCanvas(
                template: sampleTemplate(), registry: buildDefaultRegistry()),
          ),
        ),
      ),
    ));
    final size = tester.getSize(find.byType(GridCanvas));
    expect(size.width, 210);
    expect(size.height, closeTo(297, 0.5));
  });
}
