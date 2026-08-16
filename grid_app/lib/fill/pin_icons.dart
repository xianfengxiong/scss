import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The marker glyphs a satellite-diagram pin can use, keyed by the stable
/// string stored in [Pin.icon]. Keys are wire/DB values — never rename one,
/// only add. Unknown keys (from a newer peer) fall back to the classic pin.
///
/// 'pin' (neutral default) and 'bullet' are Material icons; 'ptz'/'anpr'/
/// 'radar' are custom-drawn (user-approved designs 2026-08-16: spherical PTZ
/// dome, bullet body with an "A", radar source + waves) since Material has no
/// security-industry glyphs. All are drawn upright — heading is applied by
/// the caller via Transform.rotate.
const pinIconKeys = ['pin', 'bullet', 'ptz', 'anpr', 'radar'];

/// Renders the glyph for [key] at [size] in [color].
Widget pinGlyph(String key, {required double size, required Color color}) {
  final painter = switch (key) {
    'ptz' => _PtzDomePainter(color),
    'anpr' => _AnprCameraPainter(color),
    'radar' => _RadarWavesPainter(color),
    _ => null,
  };
  if (painter != null) {
    return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(size: Size.square(size), painter: painter));
  }
  return Icon(key == 'bullet' ? Icons.videocam : Icons.location_on,
      size: size, color: color);
}

/// Base for the custom glyphs: paints in a 24×24 design space (mirroring the
/// approved SVGs) scaled to the actual size, Material-style round strokes.
abstract class _GlyphPainter extends CustomPainter {
  final Color color;
  const _GlyphPainter(this.color);

  Paint stroke([double width = 2]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint get fill => Paint()..color = color;

  void paintGlyph(Canvas canvas);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    paintGlyph(canvas);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) => old.color != color;
}

/// PTZ: ceiling bracket + full spherical dome + lens window.
class _PtzDomePainter extends _GlyphPainter {
  const _PtzDomePainter(super.color);

  @override
  void paintGlyph(Canvas canvas) {
    final s = stroke();
    canvas.drawLine(const Offset(5, 3), const Offset(19, 3), s);
    canvas.drawLine(const Offset(12, 3), const Offset(12, 5.5), s);
    canvas.drawCircle(const Offset(12, 13), 7.5, s);
    canvas.drawCircle(const Offset(12, 15), 2, fill);
  }
}

/// ANPR: bullet-camera body + trapezoid lens, an "A" on the body.
class _AnprCameraPainter extends _GlyphPainter {
  const _AnprCameraPainter(super.color);

  @override
  void paintGlyph(Canvas canvas) {
    final s = stroke();
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
    final a = stroke(1.7);
    canvas.drawPath(
        Path()
          ..moveTo(6.4, 14.6)
          ..lineTo(8.5, 9.6)
          ..lineTo(10.6, 14.6),
        a);
    canvas.drawLine(const Offset(7.2, 12.9), const Offset(9.8, 12.9), a);
  }
}

/// Radar: source dot + three quarter-circle waves fanning up-right.
class _RadarWavesPainter extends _GlyphPainter {
  const _RadarWavesPainter(super.color);

  @override
  void paintGlyph(Canvas canvas) {
    final s = stroke();
    const center = Offset(5, 19);
    canvas.drawCircle(center, 1.8, fill);
    for (final r in const [5.0, 9.0, 13.0]) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), 0,
          -math.pi / 2, false, s);
    }
  }
}
