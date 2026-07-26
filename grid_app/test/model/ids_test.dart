import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/ids.dart';

void main() {
  test('new ids carry their kind prefix and a uuid body', () {
    final t = newTemplateId();
    final s = newSurveyId();
    expect(t, startsWith('tpl_'));
    expect(s, startsWith('srv_'));
    // uuid v4: 36 chars incl. hyphens
    expect(t.length, 'tpl_'.length + 36);
    expect(s.length, 'srv_'.length + 36);
  });

  test('ids are unique across rapid calls (no clock collisions)', () {
    final seen = <String>{};
    for (var i = 0; i < 1000; i++) {
      seen.add(newTemplateId());
      seen.add(newSurveyId());
    }
    expect(seen.length, 2000);
  });
}
