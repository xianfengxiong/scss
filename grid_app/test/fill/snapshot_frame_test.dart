import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/fill/snapshot_frame.dart';

void main() {
  group('snapshotFrame', () {
    test('wide cell on a portrait viewport: full width minus margins, centred',
        () {
      final r = snapshotFrame(const Size(400, 800), 4.0);
      expect(r.width, 376);
      expect(r.height, 94);
      expect(r.left, 12);
      expect(r.center, const Offset(200, 400));
    });

    test('tall cell on a portrait viewport: height-bound', () {
      final r = snapshotFrame(const Size(400, 800), 0.25);
      expect(r.height, 776);
      expect(r.width, 194);
      expect(r.top, 12);
      expect(r.center, const Offset(200, 400));
    });

    test('square cell on a landscape viewport: height-bound, centred', () {
      final r = snapshotFrame(const Size(1000, 500), 1.0);
      expect(r.width, 476);
      expect(r.height, 476);
      expect(r.center, const Offset(500, 250));
    });

    test('custom margin', () {
      final r = snapshotFrame(const Size(100, 100), 1.0, margin: 0);
      expect(r, const Rect.fromLTWH(0, 0, 100, 100));
    });

    test('degenerate viewport never goes negative', () {
      final r = snapshotFrame(const Size(10, 10), 2.0);
      expect(r.width, 0);
      expect(r.height, 0);
    });
  });

  group('cropImageToPng', () {
    Future<ui.Image> paintImage(int w, int h) async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          Paint()..color = const Color(0xFF00FF00));
      final pic = rec.endRecording();
      final img = await pic.toImage(w, h);
      pic.dispose();
      return img;
    }

    test('crops to frame × pixelRatio and encodes PNG', () async {
      final img = await paintImage(200, 100);
      final png =
          await cropImageToPng(img, const Rect.fromLTWH(10, 5, 60, 20), 2.0);
      img.dispose();
      expect(png, isNotNull);
      final codec = await ui.instantiateImageCodec(png!);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 120);
      expect(frame.image.height, 40);
      frame.image.dispose();
      codec.dispose();
    });

    test('frame beyond the image is clamped to the image bounds', () async {
      final img = await paintImage(50, 50);
      final png =
          await cropImageToPng(img, const Rect.fromLTWH(40, 40, 100, 100), 1.0);
      img.dispose();
      final codec = await ui.instantiateImageCodec(png!);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 10);
      expect(frame.image.height, 10);
      frame.image.dispose();
      codec.dispose();
    });

    test('empty overlap → null', () async {
      final img = await paintImage(50, 50);
      final png =
          await cropImageToPng(img, const Rect.fromLTWH(100, 100, 10, 10), 1.0);
      img.dispose();
      expect(png, isNull);
    });
  });
}
