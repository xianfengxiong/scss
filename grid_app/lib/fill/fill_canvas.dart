import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../builder/border_layer.dart';
import '../builder/canvas_metrics.dart';
import '../controls/registry.dart';
import '../grid/cell_borders.dart';
import '../grid/geometry.dart';
import '../model/cell.dart';
import '../model/template.dart';

/// Renders [template] as a white A4 page fitted to the available box — the
/// SAME geometry the builder and PDF use (`cellRectMm` + `pageScale`) — but
/// draws each cell with its control's `fillWidget`, so the user fills values
/// in place (WYSIWYG). Structure is fixed; only values change.
///
/// Fit is width AND height (like the builder canvas): a phone in portrait has
/// spare height so this equals the old fit-to-width, while a wide desktop
/// window shows the whole page instead of a blown-up top slice with no way to
/// scroll (FillScreen deliberately has no ScrollView; zooming in is
/// InteractiveViewer's job).
class FillCanvas extends StatelessWidget {
  final Template template;
  final ControlRegistry registry;

  /// Current answers, keyed by each control's `dataKey`.
  final Map<String, dynamic> data;

  /// Called when a control edits its value: (control dataKey, new value).
  final void Function(String key, Object? value) onChanged;

  const FillCanvas({
    super.key,
    required this.template,
    required this.registry,
    required this.data,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final page = template.page;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          pageScale(constraints.maxWidth, page.widthMm),
          constraints.maxHeight.isFinite
              ? pageScale(constraints.maxHeight, page.heightMm)
              : double.infinity,
        );
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
              ...borderLineWidgets(controlOutlineEdges(template), scale),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(Cell cell, double scale) {
    final r = cellRectMm(template.grid, cell);
    final spec = registry.specFor(cell.type);
    final Widget content;
    if (spec == null) {
      content = Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Color(0x11FF0000)),
        child: Text('?${cell.type}',
            style: const TextStyle(fontSize: 9, color: Colors.red)),
      );
    } else {
      final key = spec.dataKey(cell);
      final value = key == null ? null : data[key];
      content = spec.fillWidget(cell, value, (v) {
        if (key != null) onChanged(key, v);
      });
    }
    return Positioned(
      left: r.leftMm * scale,
      top: r.topMm * scale,
      width: r.widthMm * scale,
      height: r.heightMm * scale,
      child: content,
    );
  }
}
