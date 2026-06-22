import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/survey.dart';

void main() {
  test('defaults to an empty data map', () {
    const s = Survey(id: 's1', templateId: 't1', name: 'My Survey');
    expect(s.data, isEmpty);
  });

  test('JSON round-trips id, templateId, name, and data', () {
    const s = Survey(
      id: 's1',
      templateId: 't1',
      name: 'My Survey',
      data: {'site_name': 'Gjirokaster', 'count': 3},
    );
    final back = Survey.fromJson(s.toJson());
    expect(back.id, 's1');
    expect(back.templateId, 't1');
    expect(back.name, 'My Survey');
    expect(back.data, {'site_name': 'Gjirokaster', 'count': 3});
  });

  test('copyWith replaces only the given fields', () {
    const s = Survey(id: 's1', templateId: 't1', name: 'A', data: {'k': 1});
    final r = s.copyWith(name: 'B', data: {'k': 2});
    expect([r.id, r.templateId, r.name], ['s1', 't1', 'B']);
    expect(r.data, {'k': 2});
  });
}
