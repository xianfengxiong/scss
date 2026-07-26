import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/sample/sample_template.dart';
import 'package:scss_grid/grid/validation.dart';
import 'package:scss_grid/controls/default_controls.dart';
import 'package:scss_grid/pdf/template_pdf.dart';

void main() {
  test('sample template is valid and renders to a single-page PDF file', () async {
    final t = sampleTemplate();

    // 1. layout is valid (in-bounds, no overlaps)
    expect(validateLayout(t), isEmpty);

    // 2. frame fits within the A4 page
    final g = t.pages[0].grid;
    expect(g.xMm + g.frameWidthMm, lessThanOrEqualTo(t.page.widthMm));
    expect(g.yMm + g.frameHeightMm, lessThanOrEqualTo(t.page.heightMm));

    // 3. renders to a real PDF file
    final doc = renderTemplate(t, const {
      'site_name': 'Gjirokaster Castle',
      'site_city': 'Gjirokaster',
    }, buildDefaultRegistry());
    final bytes = await doc.save();
    final out = File('${Directory.systemTemp.path}/scss_sample.pdf');
    await out.writeAsBytes(bytes);
    expect(await out.length(), greaterThan(0));
    // PDF magic header
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
