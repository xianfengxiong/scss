import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/cell.dart';

void main() {
  test('defaults span to 1 and json round-trips with props', () {
    final c = Cell(id: 'a', col: 1, row: 2, type: 'title', props: {'text': 'Hi'});
    expect(c.colSpan, 1);
    expect(c.rowSpan, 1);
    final back = Cell.fromJson(c.toJson());
    expect(back.toJson(), c.toJson());
    expect(back.props['text'], 'Hi');
  });
}
