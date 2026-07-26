import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/control_spec.dart';
import 'package:scss_grid/controls/registry.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/grid_frame.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/pdf/resolve_pdf_data.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

// A minimal control whose resolvePdfValue turns its value into bytes.
class _BytesControl extends ControlSpec {
  @override
  String get type => 'bytes';
  @override
  String get label => 'Bytes';
  @override
  IconData get icon => Icons.image;
  @override
  Map<String, dynamic> defaultProps() => {'key': 'k'};
  @override
  Future<Object?> resolvePdfValue(Cell cell, Object? value) async =>
      value == null ? null : Uint8List.fromList([1, 2, 3]);
  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) => pw.SizedBox();
}

Template _tpl(List<Cell> cells) => Template(
      id: 't', name: 'n', page: const PageSize.a4(),
      pages: [
        TemplatePage(
          grid: GridFrame.uniform(xMm: 0, yMm: 0, cols: 4, rows: 4, colWidthMm: 20, rowHeightMm: 10),
          cells: cells,
        ),
      ],
    );

void main() {
  test('resolvePdfData maps each cell value through its control', () async {
    final r = ControlRegistry()..register(_BytesControl());
    final t = _tpl(const [Cell(id: 'a', col: 0, row: 0, type: 'bytes', props: {'key': 'k'})]);
    final out = await resolvePdfData(t, const {'k': '/some/path.jpg', 'other': 'x'}, r);
    expect(out['k'], isA<Uint8List>());       // resolved path → bytes
    expect(out['other'], 'x');                 // untouched keys preserved
  });

  test('unregistered cell type leaves data unchanged', () async {
    final r = ControlRegistry();
    final t = _tpl(const [Cell(id: 'a', col: 0, row: 0, type: 'nope', props: {'key': 'k'})]);
    final out = await resolvePdfData(t, const {'k': 'v'}, r);
    expect(out['k'], 'v');
  });
}
