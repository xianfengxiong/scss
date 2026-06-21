import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/controls/control_spec.dart';
import 'package:scss_grid/controls/registry.dart';

class _FakeControl extends ControlSpec {
  @override
  String get type => 'fake';
  @override
  String get label => 'Fake';
  @override
  IconData get icon => Icons.crop_square;
  @override
  Map<String, dynamic> defaultProps() => {'x': 1};
  @override
  pw.Widget paintPdf(Cell cell, Map<String, dynamic> data) => pw.SizedBox();
}

void main() {
  test('register, lookup by type, and list all', () {
    final r = ControlRegistry();
    expect(r.isEmpty, isTrue);
    r.register(_FakeControl());
    expect(r.isEmpty, isFalse);
    expect(r.specFor('fake'), isA<_FakeControl>());
    expect(r.specFor('missing'), isNull);
    expect(r.all.single.label, 'Fake');
  });

  test('defaultProps is provided by the spec', () {
    expect(_FakeControl().defaultProps(), {'x': 1});
  });
}
