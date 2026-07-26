import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controls/control_spec.dart';
import '../controls/registry.dart';
import '../grid/geometry.dart';
import '../grid/hit_test.dart';
import '../model/cell.dart';
import '../model/template.dart';
import 'canvas_metrics.dart';
import 'editor_ops.dart';
import 'grid_canvas.dart';

/// Wraps [GridCanvas] with drag editing: tap to select, drag the selected cell
/// to move it, drag its right/bottom handles to resize its span, and drag the
/// frame's top/left edge handles to resize a column width / row height.
/// All gestures convert globalPosition -> grid coord via this widget's RenderBox.
class EditableCanvas extends StatefulWidget {
  final Template template;

  /// Which of the template's pages is being edited.
  final int pageIndex;

  final ControlRegistry registry;
  final String? selectedId;
  final void Function(String? id) onSelect;
  final void Function(String id, int col, int row) onMove;
  final void Function(String id, int colSpan, int rowSpan) onSpan;
  final void Function(int boundary, double deltaMm) onResizeCol;
  final void Function(int boundary, double deltaMm) onResizeRow;

  /// A control was dropped (long-press-dragged from the palette) onto grid
  /// cell (col,row). Null disables drop placement.
  final void Function(ControlSpec spec, int col, int row)? onDropControl;

  const EditableCanvas({
    super.key,
    required this.template,
    this.pageIndex = 0,
    required this.registry,
    required this.selectedId,
    required this.onSelect,
    required this.onMove,
    required this.onSpan,
    required this.onResizeCol,
    required this.onResizeRow,
    this.onDropControl,
  });

  @override
  State<EditableCanvas> createState() => _EditableCanvasState();
}

class _EditableCanvasState extends State<EditableCanvas> {
  final _key = GlobalKey();

  /// The cell being moved by the current pan — decided by where the pan
  /// STARTED, not by the selection: dragging must grab the control under
  /// the finger, otherwise a leftover selection hijacks the gesture.
  String? _dragId;

  TemplatePage get _p => widget.template.pages[widget.pageIndex];

  ({int col, int row})? _coordAt(Offset globalPos) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.width == 0) return null;
    final s = pageScale(box.size.width, widget.template.page.widthMm);
    final local = box.globalToLocal(globalPos);
    return cellCoordAtMm(_p.grid, local.dx / s, local.dy / s);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final p = _p;
    final selected =
        widget.selectedId == null ? null : _cellById(widget.selectedId!);
    return DragTarget<ControlSpec>(
      onWillAcceptWithDetails: (d) => _coordAt(d.offset) != null,
      onAcceptWithDetails: (d) {
        final c = _coordAt(d.offset);
        if (c != null) widget.onDropControl?.call(d.data, c.col, c.row);
      },
      builder: (context, candidate, rejected) => LayoutBuilder(
        builder: (context, constraints) {
          // Fit the whole A4 page in the available box (width AND height) so it
          // never needs a scroll view — a vertical scroll would steal the
          // drag-to-move gesture. Degrades to width-fit if height is unbounded.
          final scale = math.min(
            pageScale(constraints.maxWidth, t.page.widthMm),
            constraints.maxHeight.isFinite
                ? pageScale(constraints.maxHeight, t.page.heightMm)
                : double.infinity,
          );
          return SizedBox(
            width: t.page.widthMm * scale,
            height: t.page.heightMm * scale,
            child: Stack(
              key: _key,
              children: [
                // 1. render + tap-select + drag-move. The GestureDetector wraps
                //    the canvas (opaque, has a child) — the reliable pattern; the
                //    edge/span handles below are later Stack children, so they
                //    paint on top and win their own drags.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    final c = cellCoordAtMm(p.grid, d.localPosition.dx / scale,
                        d.localPosition.dy / scale);
                    final hit = c == null ? null : cellAtCoord(p, c.col, c.row);
                    widget.onSelect(hit?.id);
                  },
                  onPanStart: (d) {
                    final c = cellCoordAtMm(p.grid, d.localPosition.dx / scale,
                        d.localPosition.dy / scale);
                    final hit = c == null ? null : cellAtCoord(p, c.col, c.row);
                    _dragId = hit?.id;
                    // Grabbing a control also selects it, so the inspector
                    // and span handles follow the drag target.
                    if (hit != null && hit.id != widget.selectedId) {
                      widget.onSelect(hit.id);
                    }
                  },
                  onPanUpdate: (d) {
                    final id = _dragId;
                    if (id == null) return;
                    final c = cellCoordAtMm(p.grid, d.localPosition.dx / scale,
                        d.localPosition.dy / scale);
                    if (c != null) widget.onMove(id, c.col, c.row);
                  },
                  onPanEnd: (_) => _dragId = null,
                  onPanCancel: () => _dragId = null,
                  child: GridCanvas(
                      template: t,
                      pageIndex: widget.pageIndex,
                      registry: widget.registry,
                      selectedId: widget.selectedId),
                ),
                // 2. column-boundary handles on the frame top edge
                for (var i = 1; i < p.grid.cols; i++) _colHandle(i, scale),
                // 4. row-boundary handles on the frame left edge
                for (var j = 1; j < p.grid.rows; j++) _rowHandle(j, scale),
                // 5. span handles on the selected cell
                if (selected != null) ..._spanHandles(selected, scale),
              ],
            ),
          );
        },
      ),
    );
  }

  Cell? _cellById(String id) {
    for (final c in _p.cells) {
      if (c.id == id) return c;
    }
    return null;
  }

  double _colX(int boundary) {
    var x = _p.grid.xMm;
    for (var i = 0; i < boundary; i++) {
      x += _p.grid.colWidthsMm[i];
    }
    return x;
  }

  double _rowY(int boundary) {
    var y = _p.grid.yMm;
    for (var j = 0; j < boundary; j++) {
      y += _p.grid.rowHeightsMm[j];
    }
    return y;
  }

  Widget _colHandle(int boundary, double scale) {
    final x = _colX(boundary) * scale;
    final yTop = _p.grid.yMm * scale;
    return Positioned(
      left: (x - 8).clamp(0.0, double.infinity),
      top: (yTop - 14).clamp(0.0, double.infinity),
      width: 16,
      height: 16,
      child: GestureDetector(
        key: ValueKey('col-handle-$boundary'),
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => widget.onResizeCol(boundary, d.delta.dx / scale),
        child: const _Knob(color: Colors.deepOrange),
      ),
    );
  }

  Widget _rowHandle(int boundary, double scale) {
    final y = _rowY(boundary) * scale;
    final xLeft = _p.grid.xMm * scale;
    return Positioned(
      left: (xLeft - 14).clamp(0.0, double.infinity),
      top: (y - 8).clamp(0.0, double.infinity),
      width: 16,
      height: 16,
      child: GestureDetector(
        key: ValueKey('row-handle-$boundary'),
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => widget.onResizeRow(boundary, d.delta.dy / scale),
        child: const _Knob(color: Colors.deepOrange),
      ),
    );
  }

  List<Widget> _spanHandles(Cell cell, double scale) {
    final r = cellRectMm(_p.grid, cell);
    final rightX = r.rightMm * scale;
    final bottomY = r.bottomMm * scale;
    final midY = (r.topMm + r.heightMm / 2) * scale;
    final midX = (r.leftMm + r.widthMm / 2) * scale;
    return [
      Positioned(
        left: rightX - 8,
        top: midY - 8,
        width: 16,
        height: 16,
        child: GestureDetector(
          key: const ValueKey('span-right'),
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            final c = _coordAt(d.globalPosition);
            if (c == null) return;
            final span =
                (c.col - cell.col + 1).clamp(1, _p.grid.cols);
            widget.onSpan(cell.id, span, cell.rowSpan);
          },
          child: const _Knob(color: Colors.blue),
        ),
      ),
      Positioned(
        left: midX - 8,
        top: bottomY - 8,
        width: 16,
        height: 16,
        child: GestureDetector(
          key: const ValueKey('span-bottom'),
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            final c = _coordAt(d.globalPosition);
            if (c == null) return;
            final span =
                (c.row - cell.row + 1).clamp(1, _p.grid.rows);
            widget.onSpan(cell.id, cell.colSpan, span);
          },
          child: const _Knob(color: Colors.blue),
        ),
      ),
    ];
  }
}

class _Knob extends StatelessWidget {
  final Color color;
  const _Knob({required this.color});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
}
