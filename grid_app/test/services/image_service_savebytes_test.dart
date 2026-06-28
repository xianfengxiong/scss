import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scss_grid/services/image_service.dart';

class _FakeImage implements ImageService {
  @override
  Future<String?> capture(ImageSource source) async => null;
  @override
  Future<String> saveBytes(Uint8List bytes, {String ext = 'png'}) async =>
      '/tmp/fake.$ext';
}

void main() {
  test('ImageService exposes saveBytes with ext defaulting to png', () async {
    final ImageService svc = _FakeImage();
    expect(await svc.saveBytes(Uint8List.fromList(const [1, 2, 3])),
        '/tmp/fake.png');
    expect(await svc.saveBytes(Uint8List(0), ext: 'jpg'), '/tmp/fake.jpg');
  });
}
