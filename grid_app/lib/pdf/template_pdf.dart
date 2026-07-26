import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../controls/registry.dart';
import '../grid/cell_borders.dart';
import '../grid/geometry.dart';
import '../model/template.dart';

/// Millimetres → PDF points (1 inch = 25.4 mm = 72 pt).
const double mmToPt = 72.0 / 25.4;

/// Render [t] to one PDF page per template page, in order. Each cell is
/// absolutely positioned by its mm rectangle and drawn by its control's
/// `paintPdf`. Pagination is the user's design — nothing flows or splits.
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
  for (final page in t.pages) {
    doc.addPage(_renderPage(t, page, data, registry));
  }
  return doc;
}

pw.Page _renderPage(
  Template t,
  TemplatePage page,
  Map<String, dynamic> data,
  ControlRegistry registry,
) {
  return pw.Page(
      pageFormat: PdfPageFormat(
        t.page.widthMm * mmToPt,
        t.page.heightMm * mmToPt,
      ),
      build: (context) {
        final children = <pw.Widget>[];
        for (final cell in page.cells) {
          final r = cellRectMm(page.grid, cell);
          final spec = registry.specFor(cell.type);
          final content = spec?.paintPdf(cell, data) ??
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text('?${cell.type}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
              );
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
        // Cell border layer: each control-cell edge as a thin line centered on
        // its mm boundary (shared edges coincide → single width), matching the
        // builder/fill canvases.
        const borderPt = 0.7; // 0.7pt ≈ the 1.0 device-px canvas line (kCellBorderPx); thinner reads right in print.
        final borderColor = PdfColor.fromInt(0xFF455A64);
        for (final e in controlOutlineEdges(page)) {
          if (e.vertical) {
            children.add(pw.Positioned(
              left: e.atMm * mmToPt - borderPt / 2,
              top: e.fromMm * mmToPt,
              child: pw.Container(
                width: borderPt,
                height: (e.toMm - e.fromMm) * mmToPt,
                color: borderColor,
              ),
            ));
          } else {
            children.add(pw.Positioned(
              left: e.fromMm * mmToPt,
              top: e.atMm * mmToPt - borderPt / 2,
              child: pw.Container(
                width: (e.toMm - e.fromMm) * mmToPt,
                height: borderPt,
                color: borderColor,
              ),
            ));
          }
        }
        return pw.Stack(children: children);
      });
}
