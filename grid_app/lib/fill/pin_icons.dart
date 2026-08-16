import 'package:flutter/material.dart';

/// The marker glyphs a satellite-diagram pin can use, keyed by the stable
/// string stored in [Pin.icon]. Keys are wire/DB values — never rename one,
/// only add. Unknown keys (from a newer peer) fall back to the classic pin.
const pinIconChoices = <String, IconData>{
  'pin': Icons.location_on,
  'camera': Icons.photo_camera,
  'bolt': Icons.bolt,
  'tower': Icons.cell_tower,
};

IconData pinIconOf(String key) => pinIconChoices[key] ?? Icons.location_on;
