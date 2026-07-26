import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/sync/file_refs.dart';

void main() {
  test('collects image names from every file-bearing answer shape', () {
    final refs = referencedFileNames({
      'photo': 'a.jpg', // image control
      'images': ['b.jpg', 'c.png'], // multiImage control
      'diagram': {
        // satelliteDiagram control
        'path': 'd.png',
        'pins': [
          {'lat': 1.0, 'lon': 2.0, 'label': 'p1'}
        ],
        'center': {'lat': 1.0, 'lon': 2.0},
        'zoom': 17.0,
      },
      'note': 'plain text',
      'count': '42',
    });
    expect(refs, {'a.jpg', 'b.jpg', 'c.png', 'd.png'});
  });

  test('legacy absolute paths are reduced to their basename', () {
    final refs = referencedFileNames({
      'photo': '/data/user/0/com.scss/app_flutter/survey_images/x.jpg',
    });
    expect(refs, {'x.jpg'});
  });

  test('empty and null-ish values yield nothing', () {
    expect(referencedFileNames({}), isEmpty);
    expect(referencedFileNames({'a': null, 'b': '', 'c': []}), isEmpty);
  });

  test('duplicate references are deduped', () {
    expect(
        referencedFileNames({
          'p1': 'same.jpg',
          'p2': ['same.jpg']
        }),
        {'same.jpg'});
  });
}
