import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/template.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  test('updatedAt round-trips through toJson/fromJson', () {
    final at = DateTime(2026, 7, 26, 10, 30);
    final t = sampleTemplate().copyWith(id: 'tpl_x', updatedAt: at);
    final back = Template.fromJson(t.toJson());
    expect(back.updatedAt, at);
  });

  test('fromJson tolerates rows saved before updatedAt existed', () {
    final json = sampleTemplate().copyWith(id: 'tpl_x').toJson()
      ..remove('updatedAt');
    final back = Template.fromJson(json);
    expect(back.updatedAt, isNull);
  });
}
