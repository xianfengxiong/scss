import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Central resolver for survey image files. Every image lives in one flat
/// directory (documents/survey_images) with a UUID file name; answer values
/// store only that file name, so a survey row stays valid when synced to
/// another device. [init] runs once at startup; static so control widgets can
/// resolve synchronously during build.
class MediaPaths {
  static String? _dir;

  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'survey_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir.path;
  }

  /// Test seam: point the store at a temp dir (no platform channels), or null
  /// to reset.
  @visibleForTesting
  static set dirOverride(String? path) => _dir = path;

  /// The absolute directory all survey images live in.
  static String get dir {
    final d = _dir;
    if (d == null) throw StateError('MediaPaths.init() has not run');
    return d;
  }

  /// Absolute path for an image answer value. Values written since sync
  /// support are bare file names; legacy rows stored device-absolute paths.
  /// A legacy absolute path that no longer exists (row synced from another
  /// device) falls back to its basename under [dir]. Before init (widget
  /// tests) the value passes through unchanged.
  static String resolve(String value) {
    final d = _dir;
    if (!p.isAbsolute(value)) return d == null ? value : p.join(d, value);
    if (d == null || File(value).existsSync()) return value;
    return p.join(d, p.basename(value));
  }
}
