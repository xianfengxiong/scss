import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/fill/time_label.dart';

void main() {
  final now = DateTime.parse('2026-07-15T12:00:00');

  test('updatedLabel buckets', () {
    expect(updatedLabel(null, now), '—');
    expect(updatedLabel(now.subtract(const Duration(seconds: 30)), now),
        'just now');
    expect(updatedLabel(now.subtract(const Duration(minutes: 5)), now),
        '5m ago');
    expect(updatedLabel(now.subtract(const Duration(hours: 3)), now), '3h ago');
    expect(updatedLabel(now.subtract(const Duration(days: 2)), now), '2d ago');
    expect(updatedLabel(DateTime.parse('2026-07-01T08:00:00'), now),
        '2026-07-01');
  });

  test('dateStamp zero-pads', () {
    expect(dateStamp(DateTime(2026, 7, 5)), '2026-07-05');
    expect(dateStamp(DateTime(2026, 11, 23)), '2026-11-23');
  });
}
