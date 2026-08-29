import 'package:flutter/material.dart';

/// The marker glyphs a satellite-diagram pin can use, keyed by the stable
/// string stored in [Pin.icon]. Keys are wire/DB values — never rename one,
/// only add. Unknown keys (from a newer peer) fall back to the classic pin.
///
/// 'pin' (neutral default) is a Material icon; 'ptz'/'bullet'/'radar' are
/// real product photos (user-provided PNGs; bullet/radar de-checkerboarded
/// from their originals, 2026-08-29); 'anpr' is custom-drawn (user-approved:
/// bullet body with an "A") since Material has no security-industry glyphs.
/// All are upright — heading is applied by the caller via Transform.rotate.
const pinIconKeys = ['pin', 'bullet', 'ptz', 'anpr', 'radar'];

/// Product-photo assets, by key.
const _photoAssets = {
  'ptz': 'assets/pin_icons/ptz.png',
  'bullet': 'assets/pin_icons/bullet.png',
  'radar': 'assets/pin_icons/radar.png',
};

/// Whether a pin of [key] has an adjustable heading. The classic pin's tip
/// marks the coordinate, and the PTZ (omnidirectional, drawn from its product
/// photo) stays upright — neither rotates nor enters aim mode.
bool pinRotates(String key) => key != 'pin' && key != 'ptz';

/// Renders the glyph for [key] at [size] in [color] ([color] doesn't apply to
/// the photo assets).
Widget pinGlyph(String key, {required double size, required Color color}) {
  final asset = _photoAssets[key];
  if (asset != null) {
    return Image.asset(asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium);
  }
  if (key == 'anpr') {
    return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
            size: Size.square(size), painter: _AnprCameraPainter(color)));
  }
  return Icon(Icons.location_on, size: size, color: color);
}

/// ANPR: bullet-camera body + trapezoid lens, an "A" on the body. Paints in a
/// 24×24 design space (mirroring the approved SVG) scaled to the actual size,
/// Material-style round strokes.
class _AnprCameraPainter extends CustomPainter {
  final Color color;
  const _AnprCameraPainter(this.color);

  Paint _stroke(double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final s = _stroke(2);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 7, 13, 10), const Radius.circular(2)),
        s);
    canvas.drawPath(
        Path()
          ..moveTo(15, 10.5)
          ..lineTo(21, 7.5)
          ..lineTo(21, 16.5)
          ..lineTo(15, 13.5),
        s);
    final a = _stroke(1.7);
    canvas.drawPath(
        Path()
          ..moveTo(6.4, 14.6)
          ..lineTo(8.5, 9.6)
          ..lineTo(10.6, 14.6),
        a);
    canvas.drawLine(const Offset(7.2, 12.9), const Offset(9.8, 12.9), a);
  }

  @override
  bool shouldRepaint(covariant _AnprCameraPainter old) => old.color != color;
}
