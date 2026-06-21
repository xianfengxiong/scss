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

  /// Draw the faint interior column/row lines so the empty grid is visible
  /// (the builder needs to see the lattice; the PDF, drawn separately, does not).
  final bool showGridLines;

  /// The cell to highlight as selected (Phase 1B-ii-a), or null.
  final String? selectedId;

  const GridCanvas({
    super.key,
    required this.template,
    required this.registry,
    this.showGridLines = true,
    this.selectedId,
  });

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
              if (showGridLines) ..._gridLines(scale),
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

  /// Faint interior lines between columns and rows (the frame border is drawn
  /// separately). Count = (cols - 1) verticals + (rows - 1) horizontals.
  List<Widget> _gridLines(double scale) {
    final grid = template.grid;
    final lines = <Widget>[];
    // vertical lines at each interior column boundary
    var x = grid.xMm;
    for (var i = 0; i < grid.cols - 1; i++) {
      x += grid.colWidthsMm[i];
      lines.add(Positioned(
        left: x * scale,
        top: grid.yMm * scale,
        width: 1,
        height: grid.frameHeightMm * scale,
        child: const ColoredBox(color: Color(0x33607D8B)),
      ));
    }
    // horizontal lines at each interior row boundary
    var y = grid.yMm;
    for (var j = 0; j < grid.rows - 1; j++) {
      y += grid.rowHeightsMm[j];
      lines.add(Positioned(
        left: grid.xMm * scale,
        top: y * scale,
        width: grid.frameWidthMm * scale,
        height: 1,
        child: const ColoredBox(color: Color(0x33607D8B)),
      ));
    }
    return lines;
  }

  Widget _cell(Cell cell, double scale) {
    final r = cellRectMm(template.grid, cell);
    final spec = registry.specFor(cell.type);
    final Widget content = spec?.previewWidget(cell) ??
        Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
              border: Border.all(color: Colors.red),
              color: const Color(0x11FF0000)),
          child: Text('?${cell.type}',
              style: const TextStyle(fontSize: 9, color: Colors.red)),
        );
    return Positioned(
      left: r.leftMm * scale,
      top: r.topMm * scale,
      width: r.widthMm * scale,
      height: r.heightMm * scale,
      child: cell.id == selectedId
          ? Container(
              key: const ValueKey('cell-highlight'),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2)),
              child: content,
            )
          : content,
    );
  }
}
