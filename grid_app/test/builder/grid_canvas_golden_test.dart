import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/builder/grid_canvas.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  testWidgets('GridCanvas matches its golden for the sample template',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: GridCanvas(
                template: sampleTemplate(), registry: buildDefaultRegistry()),
          ),
        ),
      ),
    ));
    await expectLater(
      find.byType(GridCanvas),
      matchesGoldenFile('goldens/grid_canvas_sample.png'),
    );
  });
}
