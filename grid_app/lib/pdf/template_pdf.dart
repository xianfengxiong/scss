import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../controls/registry.dart';
import '../grid/cell_borders.dart';
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
          final content = spec?.paintPdf(cell, data) ??
              pw.Container(
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.red, width: 0.5)),
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
        const borderPt = 0.7;
        final borderColor = PdfColor.fromInt(0xFF455A64);
        for (final e in controlOutlineEdges(t)) {
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
      },
    ),
  );
  return doc;
}
