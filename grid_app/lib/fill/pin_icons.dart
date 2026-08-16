import 'package:flutter/material.dart';

/// The marker glyphs a satellite-diagram pin can use, keyed by the stable
/// string stored in [Pin.icon]. Keys are wire/DB values — never rename one,
/// only add. Unknown keys (from a newer peer, or the retired camera/bolt/tower
/// set that never shipped with real data) fall back to the classic pin.
///
/// 'pin' is the neutral default for a fresh pin; the rest are the device
/// types surveyed on site: bullet camera, PTZ camera, ANPR camera, radar.
const pinIconChoices = <String, IconData>{
  'pin': Icons.location_on,
  'bullet': Icons.videocam,
  'ptz': Icons.control_camera,
  'anpr': Icons.directions_car,
  'radar': Icons.radar,
};

IconData pinIconOf(String key) => pinIconChoices[key] ?? Icons.location_on;
