import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../controls/registry.dart';
import '../grid/geometry.dart';
import '../model/template.dart';

/// Millimetres → PDF points (1 inch = 25.4 mm = 72 pt).
const double mmToPt = 72.0 / 25.4;

/// Render [t] to a single A4 page. Each cell is absolutely positioned by its
/// mm rectangle and drawn by its control's `paintPdf`. No pagination.
///
/// Precondition: [t] must be a valid layout — `validateLayout(t)` empty. An
/// invalid layout (overlapping or out-of-bounds cells) has undefined output and
/// may throw at render time; callers must validate first.
pw.Document renderTemplate(
  Template t,
  Map<String, dynamic> data,
  ControlRegistry registry,
) {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        t.page.widthMm * mmToPt,
        t.page.heightMm * mmToPt,
      ),
      build: (context) {
        final children = <pw.Widget>[];
        for (final cell in t.cells) {
          final r = cellRectMm(t.grid, cell);
          final spec = registry.specFor(cell.type);
          final content = spec?.paintPdf(cell, data) ?? pw.SizedBox();
          children.add(
            pw.Positioned(
              left: r.leftMm * mmToPt,
              top: r.topMm * mmToPt,
              child: pw.SizedBox(
                width: r.widthMm * mmToPt,
                height: r.heightMm * mmToPt,
                child: content,
              ),
            ),
          );
        }
        return pw.Stack(children: children);
      },
    ),
  );
  return doc;
}
