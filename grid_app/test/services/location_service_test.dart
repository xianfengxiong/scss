import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/services/location_service.dart';

void main() {
  test('formatCoordinate uses 6 dp and a comma-space separator', () {
    expect(formatCoordinate(41.1234567, 20.1), '41.123457, 20.100000');
  });

  test('CoordinateResult.success is ok and carries the coordinate', () {
    final r = CoordinateResult.success(41.1, 20.2, accuracy: 8.0);
    expect(r.ok, isTrue);
    expect([r.lat, r.lon, r.accuracy], [41.1, 20.2, 8.0]);
    expect(r.error, isNull);
  });

  test('CoordinateResult.failure is not ok and carries the message', () {
    final r = CoordinateResult.failure('Location permission denied.');
    expect(r.ok, isFalse);
    expect(r.error, 'Location permission denied.');
    expect(r.lat, isNull);
  });
}
