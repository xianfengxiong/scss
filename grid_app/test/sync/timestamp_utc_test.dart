import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/model/tombstone.dart';
import 'package:scss_grid/sample/sample_template.dart';
import 'package:scss_grid/sync/protocol.dart';

/// LWW compares instants across two devices, so every serialized timestamp
/// must carry the UTC marker ("Z"): a bare local string is re-interpreted in
/// the *receiver's* zone and shifts by the zone difference, silently
/// inverting merge decisions (review finding, 2026-07-26).
void main() {
  final local = DateTime(2026, 7, 26, 10, 30); // a local-zone instant

  void expectUtcRoundTrip(String? serialized) {
    expect(serialized, isNotNull);
    expect(serialized, endsWith('Z'), reason: 'must be an absolute instant');
    final parsed = DateTime.parse(serialized!);
    expect(parsed.isUtc, isTrue);
    expect(parsed.isAtSameMomentAs(local), isTrue);
  }

  test('Template.updatedAt serializes as UTC', () {
    final j = sampleTemplate().copyWith(id: 't', updatedAt: local).toJson();
    expectUtcRoundTrip(j['updatedAt'] as String?);
  });

  test('Survey.updatedAt serializes as UTC', () {
    final j = Survey(id: 's', templateId: 't', name: 'S', updatedAt: local)
        .toJson();
    expectUtcRoundTrip(j['updatedAt'] as String?);
  });

  test('Tombstone.deletedAt serializes as UTC', () {
    final j = Tombstone(
            kind: Tombstone.kindSurvey, id: 's', deletedAt: local)
        .toJson();
    expectUtcRoundTrip(j['deletedAt'] as String?);
  });

  test('ManifestEntry.updatedAt serializes as UTC', () {
    final j = ManifestEntry(id: 's', updatedAt: local).toJson();
    expectUtcRoundTrip(j['updatedAt'] as String?);
  });
}
