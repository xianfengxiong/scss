import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// The snapshot frame for a satellite diagram whose cell has the given
/// width/height [aspect]: the largest rect of that aspect that fits the map
/// viewport inside [margin], centred. Snapshots are cropped to this rect so
/// they share the cell's proportions and fill it — a full portrait-phone
/// viewport dropped into a wide table cell was letterboxed to a sliver
/// (user report 2026-09-20).
Rect snapshotFrame(Size viewport, double aspect, {double margin = 12}) {
  final availW = math.max(0.0, viewport.width - 2 * margin);
  final availH = math.max(0.0, viewport.height - 2 * margin);
  var w = availW;
  var h = aspect > 0 ? w / aspect : availH;
  if (h > availH) {
    h = availH;
    w = h * aspect;
  }
  return Rect.fromLTWH(
      (viewport.width - w) / 2, (viewport.height - h) / 2, w, h);
}

/// Crop [image] (captured at [pixelRatio]) to the logical-pixel [frame] and
/// encode as PNG. The frame is clamped to the image bounds; null when the
/// clamped area is empty. Disposes nothing it did not create — the caller
/// owns [image].
Future<Uint8List?> cropImageToPng(
    ui.Image image, Rect frame, double pixelRatio) async {
  final bounds =
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  final src = Rect.fromLTWH(
    frame.left * pixelRatio,
    frame.top * pixelRatio,
    frame.width * pixelRatio,
    frame.height * pixelRatio,
  ).intersect(bounds);
  final outW = src.width.round();
  final outH = src.height.round();
  if (outW <= 0 || outH <= 0) return null;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(image, src,
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()), Paint());
  final picture = recorder.endRecording();
  final out = await picture.toImage(outW, outH);
  picture.dispose();
  try {
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    out.dispose();
  }
}
