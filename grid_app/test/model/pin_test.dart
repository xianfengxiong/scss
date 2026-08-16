import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/model/pin.dart';

void main() {
  test('default label is empty', () {
    expect(const Pin(lat: 1, lon: 2).label, '');
  });

  test('default icon is the classic pin', () {
    expect(const Pin(lat: 1, lon: 2).icon, 'pin');
  });

  test('toJson / fromJson round-trips', () {
    const p = Pin(lat: 40.5, lon: 20.1, label: 'P1', icon: 'ptz');
    final back = Pin.fromJson(p.toJson());
    expect(back.lat, 40.5);
    expect(back.lon, 20.1);
    expect(back.label, 'P1');
    expect(back.icon, 'ptz');
  });

  test('fromJson defaults missing label to empty', () {
    final p = Pin.fromJson(const {'lat': 1, 'lon': 2});
    expect(p.label, '');
  });

  test('fromJson defaults missing icon to pin (pre-icon rows)', () {
    final p = Pin.fromJson(const {'lat': 1, 'lon': 2, 'label': 'a'});
    expect(p.icon, 'pin');
  });

  test('fromJson coerces int coords to double', () {
    final p = Pin.fromJson(const {'lat': 1, 'lon': 2});
    expect(p.lat, 1.0);
    expect(p.lon, 2.0);
  });

  test('copyWith overrides only given fields', () {
    const p = Pin(lat: 1, lon: 2, label: 'a', icon: 'radar');
    final q = p.copyWith(label: 'b');
    expect(q.lat, 1);
    expect(q.lon, 2);
    expect(q.label, 'b');
    expect(q.icon, 'radar');
    expect(p.copyWith(icon: 'anpr').icon, 'anpr');
  });
}
