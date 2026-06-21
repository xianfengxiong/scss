import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();
  static const _uuid = Uuid();

  Future<Directory> _siteDir(String siteId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'site_images', siteId));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Picks from camera/gallery, compresses under ~500KB, stores it in the
  /// site's image directory and returns the saved path (or null if cancelled).
  Future<String?> captureAndStore(String siteId, ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 95);
    if (picked == null) return null;
    final dir = await _siteDir(siteId);
    final target = p.join(dir.path, '${_uuid.v4()}.jpg');

    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      target,
      quality: 82,
      minWidth: 1600,
      minHeight: 1600,
    );
    if (compressed == null) {
      // Fallback: copy the original.
      await File(picked.path).copy(target);
      return target;
    }
    return _ensureUnder500kb(compressed.path);
  }

  /// Re-compresses at lower quality until the file is under ~500KB.
  Future<String> _ensureUnder500kb(String path) async {
    var current = path;
    var quality = 68;
    while (await File(current).length() > 500 * 1024 && quality >= 30) {
      final out = p.join(
        p.dirname(current),
        '${p.basenameWithoutExtension(current)}_q$quality.jpg',
      );
      final res = await FlutterImageCompress.compressAndGetFile(
        current,
        out,
        quality: quality,
        minWidth: 1280,
        minHeight: 1280,
      );
      if (res == null) break;
      if (current != path) await _safeDelete(current);
      current = res.path;
      quality -= 16;
    }
    return current;
  }

  Future<void> deleteImage(String path) => _safeDelete(path);

  Future<void> _safeDelete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  /// Saves raw image bytes (e.g. a captured map snapshot) for a site and
  /// returns the file path.
  Future<String> saveBytes(
    String siteId,
    Uint8List bytes, {
    String ext = 'png',
    String prefix = 'diagram',
  }) async {
    final dir = await _siteDir(siteId);
    final target = p.join(dir.path, '${prefix}_${_uuid.v4()}.$ext');
    await File(target).writeAsBytes(bytes);
    return target;
  }
}
