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

  /// Persist raw [bytes] into shared storage and return the saved file name.
  /// [ext] is the file extension without the dot. No re-encoding.
  Future<String> saveBytes(Uint8List bytes, {String ext = 'png'});

  /// Persist a map snapshot. The screenshot package hands us PNG (1-3 MB per
  /// satellite diagram — the bulk of every sync payload); implementations
  /// re-encode to JPEG when a compressor is available and keep the PNG
  /// otherwise. Returns the saved file name; readers never assume the
  /// extension (`diagramPath` / `MediaPaths.resolve` are name-agnostic).
  Future<String> saveSnapshot(Uint8List pngBytes);
}

/// PNG → JPEG re-encoder; null means "unavailable, keep the PNG".
typedef SnapshotEncoder = Future<Uint8List?> Function(Uint8List png);

/// Re-encode a PNG snapshot as JPEG at quality 80, dimensions unchanged (phone
/// screens sit well under the 1600 px floor, so no downsampling kicks in).
/// Satellite imagery compresses ~5-10× this way with no visible loss. Returns
/// null when the platform compressor is unavailable (Windows has no
/// flutter_image_compress implementation; the test VM has no plugins).
Future<Uint8List?> pngToJpeg(Uint8List png) async {
  try {
    return await FlutterImageCompress.compressWithList(
      png,
      quality: 80,
      minWidth: 1600,
      minHeight: 1600,
      format: CompressFormat.jpeg,
    );
  } catch (_) {
    return null;
  }
}

// NOTE: ImagePickerImageService.capture is device-only — it invokes platform
// channels (image_picker, flutter_image_compress) that are not available in
// the Dart unit-test VM. saveBytes/saveSnapshot are plain file I/O and are
// unit-tested against a temp MediaPaths dir with an injected encoder.
class ImagePickerImageService implements ImageService {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();
  final SnapshotEncoder _encodeSnapshot;

  /// [encodeSnapshot] defaults to [pngToJpeg]; tests inject a stub.
  ImagePickerImageService({SnapshotEncoder? encodeSnapshot})
      : _encodeSnapshot = encodeSnapshot ?? pngToJpeg;

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

  @override
  Future<String> saveSnapshot(Uint8List pngBytes) async {
    final jpg = await _encodeSnapshot(pngBytes);
    // Encoder unavailable, or JPEG somehow not a win (tiny/flat image): the
    // PNG is always a valid answer, so never lose the snapshot over it.
    if (jpg == null || jpg.isEmpty || jpg.length >= pngBytes.length) {
      return saveBytes(pngBytes);
    }
    return saveBytes(jpg, ext: 'jpg');
  }
}
