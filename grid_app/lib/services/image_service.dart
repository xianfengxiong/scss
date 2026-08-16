import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'media_paths.dart';

/// Captures a photo (camera/gallery), compresses it, stores it in the shared
/// image directory ([MediaPaths.dir]), and returns the saved **file name**
/// (not a path — names stay valid across devices after sync; display resolves
/// via [MediaPaths.resolve]). Abstracted so controls can be tested with a
/// fake (the image_picker impl is device-only).
abstract class ImageService {
  /// Pick from [source], compress, store; returns the saved file name, or null
  /// if the user cancelled.
  Future<String?> capture(ImageSource source);

  /// Persist raw [bytes] (e.g. a map screenshot) into shared storage and return
  /// the saved file name. [ext] is the file extension without the dot.
  Future<String> saveBytes(Uint8List bytes, {String ext = 'png'});
}

// NOTE: ImagePickerImageService is device-only — it invokes platform channels
// (image_picker, flutter_image_compress) that are not available in the Dart
// unit-test VM. It is exercised on-device during Task 6 acceptance testing.
class ImagePickerImageService implements ImageService {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  @override
  Future<String?> capture(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 95);
    if (picked == null) return null;
    final target = p.join(MediaPaths.dir, '${_uuid.v4()}.jpg');

    final compressed = await _tryCompress(
      picked.path,
      target,
      quality: 82,
      minWidth: 1600,
      minHeight: 1600,
    );
    if (compressed == null) {
      await File(picked.path).copy(target);
      return p.basename(target);
    }
    return p.basename(await _ensureUnder500kb(compressed));
  }

  /// Compress [src] into [target]; returns the written path, or null when
  /// compression is unavailable. flutter_image_compress has no Windows
  /// implementation (throws MissingPluginException there), so any failure is
  /// treated as "couldn't compress" and callers fall back to the original.
  Future<String?> _tryCompress(
    String src,
    String target, {
    required int quality,
    required int minWidth,
    required int minHeight,
  }) async {
    try {
      final out = await FlutterImageCompress.compressAndGetFile(
        src,
        target,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
      );
      return out?.path;
    } catch (_) {
      return null;
    }
  }

  /// Re-compress until the file is under 500 KB or the quality floor is hit.
  /// Deletes each intermediate file (but never the original [path]).
  Future<String> _ensureUnder500kb(String path) async {
    final base = p.basenameWithoutExtension(path);
    final dir = p.dirname(path);
    var current = path;
    var quality = 68;
    while (await File(current).length() > 500 * 1024 && quality >= 30) {
      final out = p.join(dir, '${base}_q$quality.jpg');
      final res = await _tryCompress(
        current,
        out,
        quality: quality,
        minWidth: 1280,
        minHeight: 1280,
      );
      if (res == null) break;
      if (current != path) await _safeDelete(current);
      current = res;
      quality -= 16;
    }
    return current;
  }

  Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  @override
  Future<String> saveBytes(Uint8List bytes, {String ext = 'png'}) async {
    final name = '${_uuid.v4()}.$ext';
    await File(p.join(MediaPaths.dir, name)).writeAsBytes(bytes, flush: true);
    return name;
  }
}
