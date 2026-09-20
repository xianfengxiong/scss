import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/fill/latlon_parse.dart';

void main() {
  group('parseLatLon', () {
    test('decimal "lat, lon" (Google Maps paste)', () {
      expect(parseLatLon('25.2048, 55.2708'), (lat: 25.2048, lon: 55.2708));
    });

    test('comma without space, Chinese comma, semicolon, whitespace', () {
      expect(parseLatLon('25.2048,55.2708'), (lat: 25.2048, lon: 55.2708));
      expect(parseLatLon('25.2048,55.2708'), (lat: 25.2048, lon: 55.2708));
      expect(parseLatLon('25.2048;55.2708'), (lat: 25.2048, lon: 55.2708));
      expect(parseLatLon('  25.2048   55.2708 '), (lat: 25.2048, lon: 55.2708));
    });

    test('negative decimals', () {
      expect(parseLatLon('-33.9249, 18.4241'), (lat: -33.9249, lon: 18.4241));
      expect(parseLatLon('40.0759, -20.1389'), (lat: 40.0759, lon: -20.1389));
    });

    test('hemisphere letters, trailing and leading', () {
      expect(parseLatLon('25.2048N, 55.2708E'), (lat: 25.2048, lon: 55.2708));
      expect(parseLatLon('N25.2048 E55.2708'), (lat: 25.2048, lon: 55.2708));
      expect(
          parseLatLon('33.9249 S, 18.4241 E'), (lat: -33.9249, lon: 18.4241));
      expect(parseLatLon('40.0759n 20.1389w'), (lat: 40.0759, lon: -20.1389));
    });

    test('letters fix a longitude-first order', () {
      expect(parseLatLon('55.2708E, 25.2048N'), (lat: 25.2048, lon: 55.2708));
      expect(parseLatLon('E55.2708 25.2048'), (lat: 25.2048, lon: 55.2708));
    });

    test('degrees-minutes-seconds', () {
      final r = parseLatLon('25°12\'17.3"N 55°16\'14.9"E')!;
      expect(r.lat, closeTo(25.204806, 1e-6));
      expect(r.lon, closeTo(55.270806, 1e-6));
      final dm = parseLatLon('25°12.288\'N, 55°16.248\'E')!;
      expect(dm.lat, closeTo(25.2048, 1e-6));
      expect(dm.lon, closeTo(55.2708, 1e-6));
      final typographic = parseLatLon('33°55′29.6″S 18°25′26.8″E')!;
      expect(typographic.lat, closeTo(-33.924889, 1e-6));
      expect(typographic.lon, closeTo(18.424111, 1e-6));
    });

    test('rejects garbage, wrong arity, out-of-range, conflicting letters', () {
      expect(parseLatLon(''), isNull);
      expect(parseLatLon('hello'), isNull);
      expect(parseLatLon('25.2048'), isNull);
      expect(parseLatLon('1, 2, 3'), isNull);
      expect(parseLatLon('95, 55'), isNull);
      expect(parseLatLon('25, 190'), isNull);
      expect(parseLatLon('25N, 55N'), isNull);
      expect(parseLatLon('25°70\'N 55°E'), isNull, reason: 'minutes ≥ 60');
      expect(parseLatLon('25.2.3, 55'), isNull);
    });
  });
}
