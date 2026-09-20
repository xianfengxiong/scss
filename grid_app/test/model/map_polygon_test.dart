import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/map_polygon.dart';

const _square = [
  GeoPoint(0, 0),
  GeoPoint(0, 10),
  GeoPoint(10, 10),
  GeoPoint(10, 0),
];

void main() {
  group('GeoPoint', () {
    test('tryParse accepts {lat,lon} nums (int coerced), rejects the rest', () {
      expect(GeoPoint.tryParse(const {'lat': 1, 'lon': 2}), const GeoPoint(1, 2));
      expect(GeoPoint.tryParse(const {'lat': 1.5, 'lon': -2.5}),
          const GeoPoint(1.5, -2.5));
      expect(GeoPoint.tryParse(const {'lat': '1', 'lon': 2}), isNull);
      expect(GeoPoint.tryParse(const {'lat': 1}), isNull);
      expect(GeoPoint.tryParse('x'), isNull);
      expect(GeoPoint.tryParse(null), isNull);
    });
  });

  group('MapPolygon', () {
    test('defaults: empty label, amber, 35% fill', () {
      const p = MapPolygon(points: _square);
      expect(p.label, '');
      expect(p.color, 0xFFC107);
      expect(p.opacity, 0.35);
    });

    test('toJson / tryParse round-trips', () {
      const p = MapPolygon(
          points: _square, label: 'Site A', color: 0x2196F3, opacity: 0.6);
      final back = MapPolygon.tryParse(p.toJson())!;
      expect(back.points, _square);
      expect(back.label, 'Site A');
      expect(back.color, 0x2196F3);
      expect(back.opacity, 0.6);
    });

    test('tryParse skips malformed vertices and defaults missing style', () {
      final p = MapPolygon.tryParse({
        'points': [
          {'lat': 0, 'lon': 0},
          'junk',
          {'lat': 0, 'lon': 10},
          {'lat': 'x', 'lon': 1},
          {'lat': 10, 'lon': 10},
        ],
      })!;
      expect(p.points, const [GeoPoint(0, 0), GeoPoint(0, 10), GeoPoint(10, 10)]);
      expect(p.label, '');
      expect(p.color, MapPolygon.defaultColor);
      expect(p.opacity, MapPolygon.defaultOpacity);
    });

    test('tryParse clamps opacity and masks color to RGB', () {
      final j = {
        'points': [for (final g in _square) g.toJson()],
        'color': 0xFF2196F3, // ARGB by mistake
        'opacity': 1.7,
      };
      final p = MapPolygon.tryParse(j)!;
      expect(p.color, 0x2196F3);
      expect(p.opacity, 1.0);
      expect(MapPolygon.tryParse({...j, 'opacity': -1})!.opacity, 0.0);
    });

    test('tryParse rejects <3 valid points, non-map, missing points', () {
      expect(
          MapPolygon.tryParse({
            'points': [
              {'lat': 0, 'lon': 0},
              {'lat': 1, 'lon': 1},
            ]
          }),
          isNull);
      expect(MapPolygon.tryParse({'label': 'x'}), isNull);
      expect(MapPolygon.tryParse({'points': 'nope'}), isNull);
      expect(MapPolygon.tryParse([1, 2, 3]), isNull);
      expect(MapPolygon.tryParse(null), isNull);
    });

    test('copyWith overrides only given fields', () {
      const p = MapPolygon(points: _square, label: 'a', color: 1, opacity: 0.2);
      final q = p.copyWith(label: 'b');
      expect(q.points, _square);
      expect(q.label, 'b');
      expect(q.color, 1);
      expect(q.opacity, 0.2);
      expect(p.copyWith(color: 7).color, 7);
      expect(p.copyWith(opacity: 0.9).opacity, 0.9);
      expect(p.copyWith(points: const [GeoPoint(1, 1)]).points.length, 1);
    });

    test('contains: inside / outside / works for either winding direction', () {
      const cw = MapPolygon(points: _square);
      final ccw = MapPolygon(points: _square.reversed.toList());
      expect(cw.contains(5, 5), isTrue);
      expect(ccw.contains(5, 5), isTrue);
      expect(cw.contains(5, 15), isFalse);
      expect(cw.contains(-1, 5), isFalse);
      expect(ccw.contains(11, 11), isFalse);
    });

    test('contains: concave notch is outside', () {
      // U shape: a 10×10 square with a notch cut from the top middle.
      const u = MapPolygon(points: [
        GeoPoint(0, 0),
        GeoPoint(0, 10),
        GeoPoint(10, 10),
        GeoPoint(10, 7),
        GeoPoint(3, 7),
        GeoPoint(3, 3),
        GeoPoint(10, 3),
        GeoPoint(10, 0),
      ]);
      expect(u.contains(8, 5), isFalse, reason: 'inside the notch');
      expect(u.contains(1, 5), isTrue, reason: 'the base of the U');
      expect(u.contains(8, 1), isTrue, reason: 'left arm');
    });

    test('contains: self-intersecting bow-tie fills both lobes (non-zero)', () {
      const bowtie = MapPolygon(points: [
        GeoPoint(0, 0),
        GeoPoint(10, 10),
        GeoPoint(0, 10),
        GeoPoint(10, 0),
      ]);
      expect(bowtie.contains(5, 2), isTrue);
      expect(bowtie.contains(5, 8), isTrue);
      expect(bowtie.contains(2, 5), isFalse, reason: 'pinch point area');
    });
  });

  group('polygonIndexAt', () {
    test('returns the topmost (last) polygon containing the point', () {
      const big = MapPolygon(points: _square);
      const small = MapPolygon(points: [
        GeoPoint(4, 4),
        GeoPoint(4, 6),
        GeoPoint(6, 6),
        GeoPoint(6, 4),
      ]);
      expect(polygonIndexAt([big, small], 5, 5), 1);
      expect(polygonIndexAt([small, big], 5, 5), 1);
      expect(polygonIndexAt([big, small], 1, 1), 0);
      expect(polygonIndexAt([big, small], 20, 20), isNull);
      expect(polygonIndexAt([], 5, 5), isNull);
    });
  });
}
