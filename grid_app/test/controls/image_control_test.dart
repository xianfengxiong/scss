import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scss_grid/controls/image_control.dart';
import 'package:scss_grid/l10n/app_localizations.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/services/image_service.dart';

class _FakeImage implements ImageService {
  final String? path;
  _FakeImage(this.path);
  @override
  Future<String?> capture(ImageSource source) async => path;

  @override
  Future<String> saveBytes(Uint8List bytes, {String ext = 'png'}) async =>
      '/tmp/fake.$ext';
}

const _cell = Cell(id: 'i', col: 0, row: 0, colSpan: 4, rowSpan: 3, type: 'image',
    props: {'key': 'site_photo'});

Widget _host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SizedBox(width: 200, height: 200, child: child)));

void main() {
  test('type, defaultProps, dataKey', () {
    final c = ImageControl();
    expect(c.type, 'image');
    expect(c.defaultProps(), {'key': 'image', 'caption': ''});
    expect(c.dataKey(_cell), 'site_photo');
  });

  testWidgets('with no value, shows an add-photo button', (tester) async {
    await tester.pumpWidget(_host(
      ImageControl(image: _FakeImage('/x.jpg')).fillWidget(_cell, null, (_) {}),
    ));
    expect(find.byKey(const ValueKey('image-add')), findsOneWidget);
    expect(find.byKey(const ValueKey('image-clear')), findsNothing);
  });

  testWidgets('with a value, shows the image and a clear button that clears',
      (tester) async {
    Object? captured = 'unset';
    await tester.pumpWidget(_host(
      ImageControl(image: _FakeImage(null))
          .fillWidget(_cell, '/nonexistent.jpg', (v) => captured = v),
    ));
    expect(find.byKey(const ValueKey('image-clear')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('image-clear')));
    await tester.pump();
    expect(captured, isNull); // clear → onChanged(null)
  });

  test('resolvePdfValue: null/empty/missing-file → null', () async {
    final c = ImageControl();
    expect(await c.resolvePdfValue(_cell, null), isNull);
    expect(await c.resolvePdfValue(_cell, ''), isNull);
    expect(await c.resolvePdfValue(_cell, '/does/not/exist.jpg'), isNull);
  });

  test('paintPdf tolerates non-bytes value (renders without throwing)', () {
    final c = ImageControl();
    // data has a path string (not yet resolved) → must not throw, renders blank
    expect(() => c.paintPdf(_cell, const {'site_photo': '/x.jpg'}), returnsNormally);
    // data has bytes → renders an image without throwing
    expect(
        () => c.paintPdf(_cell, {'site_photo': Uint8List.fromList(const [1, 2, 3])}),
        returnsNormally);
  });
}
