import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where app data (the SQLite database + survey_images) lives, and how that
/// was decided.
class AppDataLocation {
  final Directory dir;

  /// Windows only: the portable `userdata\` folder beside the exe that we
  /// wanted but could not write to — [dir] is then the %APPDATA% fallback and
  /// the UI tells the user at startup. Null when no fallback happened.
  final String? unwritablePortableDir;

  const AppDataLocation(this.dir, {this.unwritablePortableDir});

  bool get fellBack => unwritablePortableDir != null;
}

AppDataLocation? _resolved;

/// Resolves the data location once per process; later calls return the same
/// answer (the database and MediaPaths must agree, and the startup notice
/// must describe what they actually used).
///
/// * **Windows** is a portable app: `userdata\` next to `scss_grid.exe`, so
///   copying the Release folder carries the data along (`data\` is taken by
///   Flutter's own bundle). When that folder isn't writable — the app was put
///   under Program Files — fall back to `%APPDATA%\com.example\scss_grid`
///   (ApplicationSupport, never the user's real Documents).
/// * **macOS** (sandbox container) and **Android** (app-private) keep their
///   Documents directory — moving them would strand data already written by
///   installed builds, and the macOS sandbox can't write beside the .app.
Future<AppDataLocation> resolveAppDataLocation() async {
  return _resolved ??= Platform.isWindows
      ? await resolveWindowsDataLocation(
          exeDir: File(Platform.resolvedExecutable).parent,
          fallback: getApplicationSupportDirectory,
        )
      : AppDataLocation(await getApplicationDocumentsDirectory());
}

/// Root directory for app data. See [resolveAppDataLocation].
Future<Directory> appDataDirectory() async =>
    (await resolveAppDataLocation()).dir;

/// The Windows rule with its inputs injected (tests run on any OS):
/// `<exeDir>/userdata` if writable, else [fallback] with the portable path
/// recorded for the notice.
Future<AppDataLocation> resolveWindowsDataLocation({
  required Directory exeDir,
  required Future<Directory> Function() fallback,
}) async {
  final portable = Directory(p.join(exeDir.path, 'userdata'));
  if (await isWritableDirectory(portable)) return AppDataLocation(portable);
  return AppDataLocation(await fallback(),
      unwritablePortableDir: portable.path);
}

/// Creates [dir] if needed and probes it with a throwaway file. False on any
/// failure (missing permission, path occupied by a file, read-only volume).
Future<bool> isWritableDirectory(Directory dir) async {
  try {
    if (!await dir.exists()) await dir.create(recursive: true);
    final probe = File(p.join(dir.path, '.write_probe_$pid'));
    await probe.writeAsString('ok', flush: true);
    await probe.delete();
    return true;
  } catch (_) {
    return false;
  }
}
