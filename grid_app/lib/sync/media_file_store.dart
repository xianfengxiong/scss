import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../services/media_paths.dart';

/// The survey-image directory as sync sees it: a flat set of UUID-named
/// files. Disk-backed in the app, in-memory in engine tests.
abstract class MediaFileStore {
  Future<Set<String>> list();
  Future<Uint8List?> read(String name);
  Future<void> write(String name, Uint8List bytes);
}

/// Rejects anything that isn't a bare file name — transported names go
/// straight into filesystem paths, so a crafted "../x" must never pass.
bool isSafeFileName(String name) =>
    name.isNotEmpty && name != '.' && name != '..' && p.basename(name) == name;

class DiskMediaFileStore implements MediaFileStore {
  @override
  Future<Set<String>> list() async {
    final dir = Directory(MediaPaths.dir);
    if (!await dir.exists()) return {};
    return {
      await for (final e in dir.list())
        if (e is File) p.basename(e.path)
    };
  }

  @override
  Future<Uint8List?> read(String name) async {
    if (!isSafeFileName(name)) return null;
    final f = File(p.join(MediaPaths.dir, name));
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    if (!isSafeFileName(name)) {
      throw ArgumentError.value(name, 'name', 'not a bare file name');
    }
    await File(p.join(MediaPaths.dir, name)).writeAsBytes(bytes, flush: true);
  }
}

class InMemoryMediaFileStore implements MediaFileStore {
  final Map<String, Uint8List> _files = {};

  @override
  Future<Set<String>> list() async => _files.keys.toSet();

  @override
  Future<Uint8List?> read(String name) async => _files[name];

  @override
  Future<void> write(String name, Uint8List bytes) async {
    if (!isSafeFileName(name)) {
      throw ArgumentError.value(name, 'name', 'not a bare file name');
    }
    _files[name] = bytes;
  }
}
