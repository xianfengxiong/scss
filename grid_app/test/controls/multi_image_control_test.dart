import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scss_grid/controls/multi_image_control.dart';
import 'package:scss_grid/l10n/app_localizations.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/services/image_service.dart';

Cell _cell({int rows = 2, int cols = 3, int min = 3}) => Cell(
      id: 'm',
      col: 0,
      row: 0,
      colSpan: 6,
      rowSpan: 4,
      type: 'multiImage',
      props: {'key': 'photos', 'rows': rows, 'cols': cols, 'min': min},
    );

class _FakeImage implements ImageService {
  final String? path;
  _FakeImage(this.path);
  @override
  Future<String?> capture(ImageSource source) async => path;
  @override
  Future<String> saveBytes(Uint8List bytes, {String ext = 'png'}) async =>
      '/tmp/fake.$ext';
}

Widget _host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SizedBox(width: 240, height: 240, child: child)));

void main() {
  test('rowsForCount = ceil(count/cols), 0 → 0', () {
    expect(rowsForCount(0, 3), 0);
    expect(rowsForCount(1, 3), 1);
    expect(rowsForCount(3, 3), 1); // 第二行全空 → 1 行（占满整高）
    expect(rowsForCount(4, 3), 2); // 进入第二行 → 2 行
    expect(rowsForCount(6, 3), 2);
  });

  test('type, defaultProps, dataKey', () {
    final c = MultiImageControl();
    expect(c.type, 'multiImage');
    expect(c.defaultProps(), {'key': 'images', 'rows': 2, 'cols': 3, 'min': 3});
    expect(c.dataKey(_cell()), 'photos');
  });

  test('validate: <min, in-range, >cap', () {
    final c = MultiImageControl();
    expect(c.validate(_cell(), null), 'At least 3, now 0');
    expect(c.validate(_cell(), ['a', 'b']), 'At least 3, now 2');
    expect(c.validate(_cell(), ['a', 'b', 'c']), isNull);
    expect(c.validate(_cell(), ['a', 'b', 'c', 'd', 'e', 'f']), isNull);
    expect(c.validate(_cell(), ['a', 'b', 'c', 'd', 'e', 'f', 'g']),
        'At most 6, now 7'); // cap = rows2*cols3 = 6
  });

  test('resolvePdfValue: paths → bytes, missing filtered, empty → null',
      () async {
    final c = MultiImageControl();
    final dir = Directory.systemTemp.createTempSync('mi_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final a = File('${dir.path}/a.bin')..writeAsBytesSync([1, 2, 3]);
    final b = File('${dir.path}/b.bin')..writeAsBytesSync([4, 5]);

    final out = await c.resolvePdfValue(
        _cell(), [a.path, '${dir.path}/missing.bin', b.path]);
    expect(out, isA<List<Uint8List>>());
    final list = out as List<Uint8List>;
    expect(list.length, 2); // missing filtered out
    expect(list[0], [1, 2, 3]);
    expect(list[1], [4, 5]);

    expect(await c.resolvePdfValue(_cell(), <String>[]), isNull);
    expect(await c.resolvePdfValue(_cell(), null), isNull);
    expect(await c.resolvePdfValue(_cell(), ['${dir.path}/none.bin']), isNull);
  });

  test('paintPdf tolerates empty / bytes / non-bytes (renders without throwing)',
      () {
    final c = MultiImageControl();
    expect(() => c.paintPdf(_cell(), const {'photos': <Uint8List>[]}),
        returnsNormally);
    expect(() => c.paintPdf(_cell(), const {'photos': ['/x.jpg']}),
        returnsNormally);
    final four = List.generate(4, (_) => Uint8List.fromList(const [1, 2, 3]));
    expect(() => c.paintPdf(_cell(), {'photos': four}), returnsNormally);
    expect(
        () => c.paintPdf(_cell(), {
              'photos': [Uint8List.fromList(const [9])]
            }),
        returnsNormally);
  });

  testWidgets('empty → add shown, no clear', (tester) async {
    await tester.pumpWidget(_host(
      MultiImageControl(image: _FakeImage('/x.jpg'))
          .fillWidget(_cell(), null, (_) {}),
    ));
    expect(find.byKey(const ValueKey('multi-image-add')), findsOneWidget);
    expect(find.byKey(const ValueKey('multi-image-clear-0')), findsNothing);
  });

  testWidgets('N photos → N clears + add still shown (below cap)',
      (tester) async {
    await tester.pumpWidget(_host(
      MultiImageControl(image: _FakeImage('/x.jpg'))
          .fillWidget(_cell(), ['/a.jpg', '/b.jpg', '/c.jpg'], (_) {}),
    ));
    expect(find.byKey(const ValueKey('multi-image-clear-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('multi-image-clear-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('multi-image-clear-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('multi-image-add')), findsOneWidget);
  });

  testWidgets('tap clear-1 → onChanged drops index 1', (tester) async {
    Object? captured = 'unset';
    await tester.pumpWidget(_host(
      MultiImageControl(image: _FakeImage(null)).fillWidget(
          _cell(), ['/a.jpg', '/b.jpg', '/c.jpg'], (v) => captured = v),
    ));
    await tester.tap(find.byKey(const ValueKey('multi-image-clear-1')));
    await tester.pump();
    expect(captured, ['/a.jpg', '/c.jpg']);
  });

  testWidgets('at capacity (6) → add hidden', (tester) async {
    await tester.pumpWidget(_host(
      MultiImageControl(image: _FakeImage('/x.jpg'))
          .fillWidget(_cell(), ['1', '2', '3', '4', '5', '6'], (_) {}),
    ));
    expect(find.byKey(const ValueKey('multi-image-add')), findsNothing);
    expect(find.byKey(const ValueKey('multi-image-clear-5')), findsOneWidget);
  });

  testWidgets('add → bottom sheet → Camera → onChanged appends',
      (tester) async {
    Object? captured = 'unset';
    await tester.pumpWidget(_host(
      MultiImageControl(image: _FakeImage('/new.jpg'))
          .fillWidget(_cell(), ['/a.jpg'], (v) => captured = v),
    ));
    await tester.tap(find.byKey(const ValueKey('multi-image-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(captured, ['/a.jpg', '/new.jpg']);
  });

  testWidgets('below min → inline red error; in-range → none', (tester) async {
    await tester.pumpWidget(_host(
      MultiImageControl(image: _FakeImage(null))
          .fillWidget(_cell(), ['/a.jpg'], (_) {}),
    ));
    expect(find.text('At least 3, now 1'), findsOneWidget);

    await tester.pumpWidget(_host(
      MultiImageControl(image: _FakeImage(null))
          .fillWidget(_cell(), ['/a.jpg', '/b.jpg', '/c.jpg'], (_) {}),
    ));
    expect(find.textContaining('At least'), findsNothing);
  });

  testWidgets('propEditor: editing Rows emits int prop', (tester) async {
    Map<String, dynamic>? captured;
    await tester.pumpWidget(_host(
      SingleChildScrollView(
        child: MultiImageControl().propEditor(_cell(), (p) => captured = p),
      ),
    ));
    // fields order: 0=Key, 1=Rows, 2=Cols, 3=Min
    await tester.enterText(find.byType(TextFormField).at(1), '4');
    expect(captured, isNotNull);
    expect(captured!['rows'], 4);
    expect(captured!['rows'], isA<int>());
    expect(captured!['key'], 'photos'); // preserved
  });
}
