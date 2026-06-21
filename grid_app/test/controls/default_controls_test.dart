import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';

void main() {
  test('default registry has title and field', () {
    final r = buildDefaultRegistry();
    expect(r.specFor('title'), isNotNull);
    expect(r.specFor('field'), isNotNull);
    expect(r.specFor('title')!.defaultProps()['text'], 'Title');
    expect(r.specFor('field')!.defaultProps()['valueType'], 'text');
  });
}
