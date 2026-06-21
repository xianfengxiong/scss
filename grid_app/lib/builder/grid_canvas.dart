import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../grid/geometry.dart';
import '../model/cell.dart';
import '../model/template.dart';

/// Renders [template] as a white A4 page scaled to the available width.
/// Cells are positioned by [cellRectMm] (the same geometry the PDF uses) and
/// drawn via each control's `previewWidget`, so the canvas matches the PDF.
/// Read-only in Phase 1B-i (no editing).
class GridCanvas extends StatelessWidget {
  final Template template;
  final ControlRegistry registry;

  const GridCanvas({super.key, required this.template, required this.registry});

  @override
  Widget build(BuildContext context) {
    final page = template.page;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / page.widthMm;
        final grid = template.grid;
        return Container(
          width: page.widthMm * scale,
          height: page.heightMm * scale,
          color: Colors.white,
          child: Stack(
            children: [
              // grid frame border (the PDF output region)
              Positioned(
                left: grid.xMm * scale,
                top: grid.yMm * scale,
                width: grid.frameWidthMm * scale,
                height: grid.frameHeightMm * scale,
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF607D8B))),
                ),
              ),
              for (final cell in template.cells) _cell(cell, scale),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(Cell cell, double scale) {
    final r = cellRectMm(template.grid, cell);
    final spec = registry.specFor(cell.type);
    return Positioned(
      left: r.leftMm * scale,
      top: r.topMm * scale,
      width: r.widthMm * scale,
      height: r.heightMm * scale,
      child: spec?.previewWidget(cell) ?? const SizedBox.shrink(),
    );
  }
}
