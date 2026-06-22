import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/field_control.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/services/location_service.dart';

class _FakeOk implements LocationService {
  @override
  Future<CoordinateResult> getCoordinate() async =>
      CoordinateResult.success(41.1234567, 20.7654321);
}

class _FakeFail implements LocationService {
  @override
  Future<CoordinateResult> getCoordinate() async =>
      CoordinateResult.failure('Location permission denied.');
}

const _coordCell = Cell(id: 'c', col: 0, row: 0, colSpan: 6, type: 'field',
    props: {'label': 'GPS', 'key': 'site_gps', 'valueType': 'coordinate',
        'labelCols': 2});

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 360, height: 80, child: child)));

void main() {
  testWidgets('GPS button fills the value with a formatted coordinate',
      (tester) async {
    Object? captured;
    await tester.pumpWidget(_host(
      FieldControl(location: _FakeOk())
          .fillWidget(_coordCell, null, (v) => captured = v),
    ));
    expect(find.byKey(const ValueKey('gps-capture')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('gps-capture')));
    await tester.pumpAndSettle();
    expect(captured, '41.123457, 20.765432');
    expect(find.text('41.123457, 20.765432'), findsOneWidget);
  });

  testWidgets('GPS failure shows a SnackBar and does not fill the value',
      (tester) async {
    Object? captured;
    await tester.pumpWidget(_host(
      FieldControl(location: _FakeFail())
          .fillWidget(_coordCell, null, (v) => captured = v),
    ));
    await tester.tap(find.byKey(const ValueKey('gps-capture')));
    await tester.pumpAndSettle();
    expect(find.text('Location permission denied.'), findsOneWidget);
    expect(captured, isNull);
  });

  testWidgets('with no LocationService, a coordinate field is a plain text input',
      (tester) async {
    await tester.pumpWidget(_host(
      FieldControl().fillWidget(_coordCell, 'old', (_) {}),
    ));
    expect(find.byKey(const ValueKey('gps-capture')), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
  });
}
