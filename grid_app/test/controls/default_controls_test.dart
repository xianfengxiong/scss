import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/controls/field_control.dart';
import 'package:scss_grid/model/cell.dart';

void main() {
  test('default registry has title and field', () {
    final r = buildDefaultRegistry();
    expect(r.specFor('title'), isNotNull);
    expect(r.specFor('field'), isNotNull);
    expect(r.specFor('title')!.defaultProps()['text'], 'Title');
    expect(r.specFor('field')!.defaultProps()['valueType'], 'text');
  });

  test('FieldControl.paintPdf does not crash on bad labelCols (0/negative)', () {
    final f = FieldControl();
    // labelCols 0 and -1 must not produce a flex <= 0 (would throw at render).
    expect(() => f.paintPdf(
        const Cell(id: 'x', col: 0, row: 0, colSpan: 4, type: 'field',
            props: {'label': 'L', 'key': 'k', 'labelCols': 0}), const {}),
        returnsNormally);
    expect(() => f.paintPdf(
        const Cell(id: 'y', col: 0, row: 0, colSpan: 4, type: 'field',
            props: {'label': 'L', 'key': 'k', 'labelCols': -1}), const {}),
        returnsNormally);
  });

  test('FieldControl.paintPdf accepts a double-valued labelCols (JSON/Drift safe)', () {
    final f = FieldControl();
    expect(() => f.paintPdf(
        const Cell(id: 'd', col: 0, row: 0, colSpan: 4, type: 'field',
            props: {'label': 'L', 'key': 'k', 'labelCols': 2.0}), const {}),
        returnsNormally);
  });
}
