import 'package:path/path.dart' as p;

const _imageExts = {'.jpg', '.jpeg', '.png', '.webp'};

/// Image file names referenced anywhere in a survey's answers, deduped.
///
/// Answer values are scanned recursively for strings with an image extension:
/// `image` stores one name, `multiImage` a list, `satelliteDiagram` a map
/// whose `path` entry is one. Scanning by shape instead of walking the
/// template through the control registry means this works even when the
/// template hasn't arrived yet and never misses a future file-bearing
/// control. Only the basename is kept (legacy rows stored absolute paths).
/// A false positive (a text answer ending in ".jpg") merely yields a name
/// the sync layer won't find on disk and skips.
Set<String> referencedFileNames(Map<String, dynamic> surveyData) {
  final out = <String>{};
  void scan(Object? v) {
    if (v is String) {
      if (_imageExts.contains(p.extension(v).toLowerCase())) {
        out.add(p.basename(v));
      }
    } else if (v is List) {
      v.forEach(scan);
    } else if (v is Map) {
      v.values.forEach(scan);
    }
  }

  scan(surveyData);
  return out;
}
