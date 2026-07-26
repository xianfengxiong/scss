import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scss_grid/services/media_paths.dart';

void main() {
  tearDown(() => MediaPaths.dirOverride = null);

  test('bare file name resolves under the store directory', () {
    MediaPaths.dirOverride = '/store';
    expect(MediaPaths.resolve('a.jpg'), p.join('/store', 'a.jpg'));
  });

  test('legacy absolute path that still exists is used as-is', () async {
    final tmp = await Directory.systemTemp.createTemp('media_paths');
    addTearDown(() => tmp.delete(recursive: true));
    final f = File(p.join(tmp.path, 'x.jpg'));
    await f.writeAsBytes(const [1]);
    MediaPaths.dirOverride = '/store';
    expect(MediaPaths.resolve(f.path), f.path);
  });

  test('foreign absolute path (synced row) falls back to basename in store',
      () {
    MediaPaths.dirOverride = '/store';
    expect(MediaPaths.resolve('/data/user/0/app/survey_images/x.jpg'),
        p.join('/store', 'x.jpg'));
  });

  test('before init values pass through unchanged (widget tests)', () {
    expect(MediaPaths.resolve('a.jpg'), 'a.jpg');
    expect(MediaPaths.resolve('/missing/abs/a.jpg'), '/missing/abs/a.jpg');
  });

  test('dir throws before init', () {
    expect(() => MediaPaths.dir, throwsStateError);
  });
}
