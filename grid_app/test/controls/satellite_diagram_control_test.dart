import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:scss_grid/controls/satellite_diagram_control.dart';
import 'package:scss_grid/l10n/app_localizations.dart';
import 'package:scss_grid/model/cell.dart';
import 'package:scss_grid/model/pin.dart';

const _cell = Cell(
    id: 's', col: 0, row: 0, colSpan: 4, rowSpan: 3, type: 'satelliteDiagram',
    props: {'key': 'diagram', 'caption': 'Junction A'});

/// A minimal valid 1×1 PNG, so `pw.MemoryImage` decodes (and paintPdf builds the
/// real Center/Column) instead of throwing on garbage bytes.
final _validPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82, //
]);

void main() {
  group('value parsing helpers', () {
    test('diagramPath extracts non-empty path, else null', () {
      expect(diagramPath({'path': '/x.png'}), '/x.png');
      expect(diagramPath({'path': ''}), isNull);
      expect(diagramPath({'pins': []}), isNull);
      expect(diagramPath(null), isNull);
      expect(diagramPath('not a map'), isNull);
    });

    test('diagramPins parses well-formed pins, skips malformed', () {
      final pins = diagramPins({
        'pins': [
          {'lat': 1, 'lon': 2, 'label': 'P1'},
          {'lat': 3.5, 'lon': 4.5},
          {'lat': 'bad', 'lon': 2}, // skipped: lat not num
          'garbage', // skipped: not a map
        ],
      });
      expect(pins.length, 2);
      expect(pins[0], isA<Pin>());
      expect(pins[0].label, 'P1');
      expect(pins[1].lat, 3.5);
      expect(pins[1].label, '');
    });

    // Regression: save → re-enter lost icon/rotation because diagramPins
    // rebuilt Pin from lat/lon/label only (device icons vanished).
    test('diagramPins keeps icon and rotation; defaults when absent', () {
      final pins = diagramPins({
        'pins': [
          {'lat': 1, 'lon': 2, 'icon': 'ptz', 'rotation': 135},
          {'lat': 3, 'lon': 4}, // pre-icon row
        ],
      });
      expect(pins[0].icon, 'ptz');
      expect(pins[0].rotation, 135.0);
      expect(pins[1].icon, 'pin');
      expect(pins[1].rotation, 0);
    });

    test('pins round-trip through toJson → diagramPins unchanged', () {
      const p = Pin(lat: 9, lon: 8, label: 'cam', icon: 'bullet', rotation: 270);
      final back = diagramPins({
        'pins': [p.toJson()]
      }).single;
      expect(back.icon, 'bullet');
      expect(back.rotation, 270.0);
      expect(back.label, 'cam');
    });

    test('diagramPins on missing/wrong-typed pins → empty', () {
      expect(diagramPins(null), isEmpty);
      expect(diagramPins({'pins': 'nope'}), isEmpty);
      expect(diagramPins({}), isEmpty);
    });

    test('diagramCenter parses {lat,lon}, else null', () {
      final c = diagramCenter({'center': {'lat': 40.0, 'lon': 20.0}});
      expect(c, isA<LatLng>());
      expect(c!.latitude, 40.0);
      expect(c.longitude, 20.0);
      expect(diagramCenter({'center': {'lat': 1}}), isNull);
      expect(diagramCenter(null), isNull);
    });

    test('diagramZoom parses num, defaults 17', () {
      expect(diagramZoom({'zoom': 18.5}), 18.5);
      expect(diagramZoom({'zoom': 16}), 16.0);
      expect(diagramZoom({}), 17.0);
      expect(diagramZoom(null), 17.0);
    });
  });

  test('type, defaultProps, dataKey', () {
    final c = SatelliteDiagramControl();
    expect(c.type, 'satelliteDiagram');
    expect(c.defaultProps(), {'key': 'diagram', 'caption': ''});
    expect(c.dataKey(_cell), 'diagram');
  });

  test('validate: empty value is legal (null)', () {
    final c = SatelliteDiagramControl();
    expect(c.validate(_cell, null), isNull);
    expect(c.validate(_cell, {'path': '/x.png'}), isNull);
  });

  group('resolvePdfValue', () {
    test('null / no-path / missing-file → null', () async {
      final c = SatelliteDiagramControl();
      expect(await c.resolvePdfValue(_cell, null), isNull);
      expect(await c.resolvePdfValue(_cell, {'path': ''}), isNull);
      expect(await c.resolvePdfValue(_cell, {'path': '/does/not/exist.png'}),
          isNull);
    });

    test('existing file → bytes', () async {
      final dir = await Directory.systemTemp.createTemp('sat_test');
      final f = File('${dir.path}/snap.png');
      await f.writeAsBytes(const [9, 8, 7]);
      final c = SatelliteDiagramControl();
      final out = await c.resolvePdfValue(_cell, {'path': f.path});
      expect(out, isA<Uint8List>());
      expect((out as Uint8List).toList(), [9, 8, 7]);
      await dir.delete(recursive: true);
    });
  });

  group('paintPdf', () {
    test('non-bytes value → renders blank without throwing', () {
      final c = SatelliteDiagramControl();
      expect(() => c.paintPdf(_cell, const {'diagram': {'path': '/x.png'}}),
          returnsNormally);
      expect(() => c.paintPdf(_cell, const {}), returnsNormally);
    });

    test('bytes value → renders without throwing (with and without caption)',
        () {
      final c = SatelliteDiagramControl();
      final bytes = Uint8List.fromList(const [1, 2, 3]);
      expect(() => c.paintPdf(_cell, {'diagram': bytes}), returnsNormally);
      const noCap = Cell(
          id: 's2', col: 0, row: 0, colSpan: 4, rowSpan: 3,
          type: 'satelliteDiagram', props: {'key': 'diagram', 'caption': ''});
      expect(() => c.paintPdf(noCap, {'diagram': bytes}), returnsNormally);
    });

    test('no caption → image centered in the cell (pw.Center)', () {
      // Guards WYSIWYG: pw.Image sizes to the fitted image and the cell SizedBox
      // would otherwise pin it top-left; pw.Center keeps it centered like fill.
      final c = SatelliteDiagramControl();
      const noCap = Cell(
          id: 's2', col: 0, row: 0, colSpan: 4, rowSpan: 3,
          type: 'satelliteDiagram', props: {'key': 'diagram', 'caption': ''});
      expect(c.paintPdf(noCap, {'diagram': _validPng}), isA<pw.Center>());
    });

    test('with caption → Column(image, caption)', () {
      final c = SatelliteDiagramControl();
      // _cell has caption 'Junction A'.
      expect(c.paintPdf(_cell, {'diagram': _validPng}), isA<pw.Column>());
    });
  });

  Widget host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: SizedBox(width: 200, height: 200, child: child)));

  testWidgets('fillWidget: no value → shows open-map button, no clear',
      (tester) async {
    await tester.pumpWidget(host(
        SatelliteDiagramControl().fillWidget(_cell, null, (_) {})));
    expect(find.byKey(const ValueKey('satellite-open')), findsOneWidget);
    expect(find.byKey(const ValueKey('satellite-clear')), findsNothing);
  });

  testWidgets('fillWidget: with value → shows thumbnail + clear that clears',
      (tester) async {
    Object? captured = 'unset';
    await tester.pumpWidget(host(SatelliteDiagramControl()
        .fillWidget(_cell, {'path': '/nonexistent.png'}, (v) => captured = v)));
    expect(find.byKey(const ValueKey('satellite-clear')), findsOneWidget);
    expect(find.byKey(const ValueKey('satellite-open')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('satellite-clear')));
    await tester.pump();
    expect(captured, isNull);
  });

  testWidgets('propEditor edits key and caption', (tester) async {
    Map<String, dynamic>? props;
    await tester.pumpWidget(host(
        SatelliteDiagramControl().propEditor(_cell, (p) => props = p)));
    await tester.enterText(
        find.byKey(const ValueKey('satellite-key')), 'diag2');
    expect(props!['key'], 'diag2');
    await tester.enterText(
        find.byKey(const ValueKey('satellite-caption')), 'Pole row');
    expect(props!['caption'], 'Pole row');
  });
}
