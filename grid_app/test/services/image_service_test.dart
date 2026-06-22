import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scss_grid/services/image_service.dart';

class _FakeImageService implements ImageService {
  String? next;
  ImageSource? lastSource;
  _FakeImageService(this.next);
  @override
  Future<String?> capture(ImageSource source) async {
    lastSource = source;
    return next;
  }
}

void main() {
  test('ImageService.capture returns a stored path (fake)', () async {
    final s = _FakeImageService('/docs/survey_images/abc.jpg');
    expect(await s.capture(ImageSource.camera), '/docs/survey_images/abc.jpg');
    expect(s.lastSource, ImageSource.camera);
  });

  test('capture returns null when cancelled (fake)', () async {
    final s = _FakeImageService(null);
    expect(await s.capture(ImageSource.gallery), isNull);
  });
}
