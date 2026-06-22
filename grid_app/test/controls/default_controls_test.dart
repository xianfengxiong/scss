import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';

void main() {
  test('default registry has title, label, text, number, coordinate', () {
    final r = buildDefaultRegistry();
    expect(r.specFor('title'), isNotNull);
    expect(r.specFor('label'), isNotNull);
    expect(r.specFor('text'), isNotNull);
    expect(r.specFor('number'), isNotNull);
    expect(r.specFor('coordinate'), isNotNull);
    expect(r.specFor('field'), isNull);
  });

  test('registry control types match expected set', () {
    final r = buildDefaultRegistry();
    final types = r.all.map((s) => s.type).toSet();
    expect(types, {'title', 'label', 'text', 'number', 'coordinate'});
  });

  test('text defaultProps has key and hint', () {
    final r = buildDefaultRegistry();
    expect(r.specFor('text')!.defaultProps()['key'], 'text');
    expect(r.specFor('text')!.defaultProps()['hint'], '');
  });

  test('coordinate defaultProps has key', () {
    final r = buildDefaultRegistry();
    expect(r.specFor('coordinate')!.defaultProps()['key'], 'coordinate');
  });
}
