import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scss_grid/services/image_service.dart';
import 'package:scss_grid/services/media_paths.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('snapshot_test');
    MediaPaths.dirOverride = tmp.path;
  });
  tearDown(() async {
    MediaPaths.dirOverride = null;
    await tmp.delete(recursive: true);
  });

  final png = Uint8List.fromList(List<int>.generate(1000, (i) => i % 251));

  test('saveSnapshot stores the JPEG re-encode under a bare .jpg name',
      () async {
    final jpg = Uint8List.fromList(const [0xFF, 0xD8, 1, 2, 3]);
    Uint8List? fed;
    final svc = ImagePickerImageService(encodeSnapshot: (b) async {
      fed = b;
      return jpg;
    });
    final name = await svc.saveSnapshot(png);
    expect(fed, png, reason: 'the raw PNG goes to the encoder');
    expect(p.extension(name), '.jpg');
    expect(p.basename(name), name, reason: 'file name, not a path');
    expect(await File(p.join(tmp.path, name)).readAsBytes(), jpg);
  });

  test('saveSnapshot keeps the PNG when no encoder is available', () async {
    final svc = ImagePickerImageService(encodeSnapshot: (_) async => null);
    final name = await svc.saveSnapshot(png);
    expect(p.extension(name), '.png');
    expect(await File(p.join(tmp.path, name)).readAsBytes(), png);
  });

  test('saveSnapshot keeps the PNG when JPEG would not be smaller', () async {
    final svc = ImagePickerImageService(
        encodeSnapshot: (_) async => Uint8List(png.length + 1));
    final name = await svc.saveSnapshot(png);
    expect(p.extension(name), '.png');
    expect(await File(p.join(tmp.path, name)).readAsBytes(), png);
  });

  test('pngToJpeg yields null (never throws) without a platform compressor',
      () async {
    // The test VM has no flutter_image_compress plugin — same shape as
    // Windows, where the plugin has no implementation.
    expect(await pngToJpeg(png), isNull);
  });
}
