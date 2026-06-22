import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/coordinate_control.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/services/location_service.dart';

class _FakeOk implements LocationService {
  @override
  Future<CoordinateResult> getCoordinate() async =>
      CoordinateResult.success(41.1234567, 20.7654321);
}

const _cell = Cell(id: 'c', col: 0, row: 0, colSpan: 6, type: 'coordinate',
    props: {'key': 'site_gps'});

class _FakeFail implements LocationService {
  @override
  Future<CoordinateResult> getCoordinate() async =>
      CoordinateResult.failure('Location permission denied.');
}

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 360, height: 80, child: child)));

void main() {
  test('type, defaultProps, dataKey', () {
    final c = CoordinateControl();
    expect(c.type, 'coordinate');
    expect(c.defaultProps(), {'key': 'coordinate'});
    expect(c.dataKey(_cell), 'site_gps');
  });

  testWidgets('GPS button fills the value with a formatted coordinate',
      (tester) async {
    Object? captured;
    await tester.pumpWidget(_host(
      CoordinateControl(location: _FakeOk())
          .fillWidget(_cell, null, (v) => captured = v),
    ));
    expect(find.byKey(const ValueKey('gps-capture')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('gps-capture')));
    await tester.pumpAndSettle();
    expect(captured, '41.123457, 20.765432');
  });

  testWidgets('GPS failure surfaces a SnackBar and does not fill the value',
      (tester) async {
    Object? captured;
    await tester.pumpWidget(_host(
      CoordinateControl(location: _FakeFail())
          .fillWidget(_cell, null, (v) => captured = v),
    ));
    await tester.tap(find.byKey(const ValueKey('gps-capture')));
    await tester.pumpAndSettle();
    expect(find.text('Location permission denied.'), findsOneWidget);
    expect(captured, isNull);
  });

  testWidgets('with no LocationService, coordinate is a plain text input',
      (tester) async {
    await tester.pumpWidget(_host(
      CoordinateControl().fillWidget(_cell, 'old', (_) {}),
    ));
    expect(find.byKey(const ValueKey('gps-capture')), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
  });
}
