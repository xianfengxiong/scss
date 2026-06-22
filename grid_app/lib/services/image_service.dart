import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Captures a photo (camera/gallery), compresses it, stores it in the app
/// documents directory, and returns the file path. Abstracted so controls can
/// be tested with a fake (the image_picker impl is device-only).
abstract class ImageService {
  /// Pick from [source], compress, store; returns the saved file path, or null
  /// if the user cancelled.
  Future<String?> capture(ImageSource source);
}

// NOTE: ImagePickerImageService is device-only — it invokes platform channels
// (image_picker, flutter_image_compress) that are not available in the Dart
// unit-test VM. It is exercised on-device during Task 6 acceptance testing.
class ImagePickerImageService implements ImageService {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'survey_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<String?> capture(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 95);
    if (picked == null) return null;
    final dir = await _dir();
    final target = p.join(dir.path, '${_uuid.v4()}.jpg');

    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      target,
      quality: 82,
      minWidth: 1600,
      minHeight: 1600,
    );
    if (compressed == null) {
      await File(picked.path).copy(target);
      return target;
    }
    return _ensureUnder500kb(compressed.path);
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

  Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
