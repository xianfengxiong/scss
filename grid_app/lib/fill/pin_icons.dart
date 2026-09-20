import 'package:flutter/material.dart';

/// The marker glyphs a satellite-diagram pin can use, keyed by the stable
/// string stored in [Pin.icon]. Keys are wire/DB values — never rename one,
/// only add. Unknown keys (from a newer peer) fall back to the classic pin.
///
/// 'pin' (neutral default) is a Material icon; 'ptz'/'bullet'/'radar'/'anpr'
/// are real product photos (user-provided PNGs; bullet/radar de-checkerboarded
/// by edge flood-fill 2026-08-29; anpr — a white housing on a light checker,
/// which flood-fill hollowed out — cut out with macOS Vision subject lifting
/// 2026-09-20, replacing the earlier line-drawn glyph the user found
/// "see-through"). All are upright — heading is applied by the caller via
/// Transform.rotate.
const pinIconKeys = ['pin', 'bullet', 'ptz', 'anpr', 'radar'];

/// Product-photo assets, by key.
const _photoAssets = {
  'ptz': 'assets/pin_icons/ptz.png',
  'bullet': 'assets/pin_icons/bullet.png',
  'radar': 'assets/pin_icons/radar.png',
  'anpr': 'assets/pin_icons/anpr.png',
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
  return Icon(Icons.location_on, size: size, color: color);
}
