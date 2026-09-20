import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scss_grid/services/app_dirs.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('app_dirs'));
  tearDown(() => tmp.delete(recursive: true));

  group('resolveWindowsDataLocation', () {
    test('writable exe folder → userdata beside the exe, no fallback',
        () async {
      var fallbackCalled = false;
      final loc = await resolveWindowsDataLocation(
        exeDir: tmp,
        fallback: () async {
          fallbackCalled = true;
          return tmp;
        },
      );
      expect(loc.dir.path, p.join(tmp.path, 'userdata'));
      expect(await loc.dir.exists(), isTrue, reason: 'created on resolve');
      expect(loc.fellBack, isFalse);
      expect(loc.unwritablePortableDir, isNull);
      expect(fallbackCalled, isFalse);
    });

    test('userdata not writable → fallback dir, portable path recorded',
        () async {
      // A file squatting on the name makes the directory impossible to create.
      await File(p.join(tmp.path, 'userdata')).writeAsString('x');
      final appdata = Directory(p.join(tmp.path, 'appdata'));
      final loc = await resolveWindowsDataLocation(
          exeDir: tmp, fallback: () async => appdata);
      expect(loc.dir.path, appdata.path);
      expect(loc.fellBack, isTrue);
      expect(loc.unwritablePortableDir, p.join(tmp.path, 'userdata'));
    });
  });

  group('isWritableDirectory', () {
    test('creates a missing directory and leaves no probe behind', () async {
      final d = Directory(p.join(tmp.path, 'a', 'b'));
      expect(await isWritableDirectory(d), isTrue);
      expect(await d.exists(), isTrue);
      expect(await d.list().isEmpty, isTrue);
    });

    test('path occupied by a file → false', () async {
      final f = File(p.join(tmp.path, 'taken'));
      await f.writeAsString('x');
      expect(await isWritableDirectory(Directory(f.path)), isFalse);
    });
  });
}
