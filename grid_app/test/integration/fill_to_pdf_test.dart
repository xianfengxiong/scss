import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/model/survey.dart';
import 'package:scss_grid/pdf/template_pdf.dart';
import 'package:scss_grid/sample/sample_template.dart';

void main() {
  test('a filled survey renders its values into a single-page PDF', () async {
    final t = sampleTemplate();
    const survey = Survey(
      id: 's1',
      templateId: 'sample',
      name: 'Filled',
      data: {'site_name': 'Gjirokaster', 'site_city': 'Gjirokaster'},
    );

    final doc = renderTemplate(t, survey.data, buildDefaultRegistry());
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
