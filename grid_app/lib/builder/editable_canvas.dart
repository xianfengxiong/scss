import 'package:flutter/material.dart';

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
  final ControlRegistry registry;
  final String? selectedId;
  final void Function(String? id) onSelect;
  final void Function(String id, int col, int row) onMove;
  final void Function(String id, int colSpan, int rowSpan) onSpan;
  final void Function(int boundary, double deltaMm) onResizeCol;
  final void Function(int boundary, double deltaMm) onResizeRow;

  const EditableCanvas({
    super.key,
    required this.template,
    required this.registry,
    required this.selectedId,
    required this.onSelect,
    required this.onMove,
    required this.onSpan,
    required this.onResizeCol,
    required this.onResizeRow,
  });

  @override
  State<EditableCanvas> createState() => _EditableCanvasState();
}

class _EditableCanvasState extends State<EditableCanvas> {
  final _key = GlobalKey();

  double get _scale {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || box.size.width == 0) return 1;
    return pageScale(box.size.width, widget.template.page.widthMm);
  }

  ({int col, int row})? _coordAt(Offset globalPos) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPos);
    final s = _scale;
    return cellCoordAtMm(
        widget.template.grid, local.dx / s, local.dy / s);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final selected = widget.selectedId == null
        ? null
        : _cellById(widget.selectedId!);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = pageScale(constraints.maxWidth, t.page.widthMm);
        return SizedBox(
          width: t.page.widthMm * scale,
          height: t.page.heightMm * scale,
          child: Stack(
            key: _key,
            children: [
              // 1. render
              GridCanvas(
                  template: t, registry: widget.registry,
                  selectedId: widget.selectedId),
              // 2. tap-select + drag-move (full bleed, under the handles)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (d) {
                    final c = _coordAt(d.globalPosition);
                    final hit = c == null
                        ? null
                        : cellAtCoord(t, c.col, c.row);
                    widget.onSelect(hit?.id);
                  },
                  onPanUpdate: (d) {
                    final id = widget.selectedId;
                    if (id == null) return;
                    final c = _coordAt(d.globalPosition);
                    if (c != null) widget.onMove(id, c.col, c.row);
                  },
                ),
              ),
              // 3. column-boundary handles on the frame top edge
              for (var i = 1; i < t.grid.cols; i++)
                _colHandle(i, scale),
              // 4. row-boundary handles on the frame left edge
              for (var j = 1; j < t.grid.rows; j++)
                _rowHandle(j, scale),
              // 5. span handles on the selected cell
              if (selected != null) ..._spanHandles(selected, scale),
            ],
          ),
        );
      },
    );
  }

  Cell? _cellById(String id) {
    for (final c in widget.template.cells) {
      if (c.id == id) return c;
    }
    return null;
  }

  double _colX(int boundary) {
    var x = widget.template.grid.xMm;
    for (var i = 0; i < boundary; i++) {
      x += widget.template.grid.colWidthsMm[i];
    }
    return x;
  }

  double _rowY(int boundary) {
    var y = widget.template.grid.yMm;
    for (var j = 0; j < boundary; j++) {
      y += widget.template.grid.rowHeightsMm[j];
    }
    return y;
  }

  Widget _colHandle(int boundary, double scale) {
    final x = _colX(boundary) * scale;
    final yTop = widget.template.grid.yMm * scale;
    return Positioned(
      left: x - 8,
      top: yTop - 14,
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
    final xLeft = widget.template.grid.xMm * scale;
    return Positioned(
      left: xLeft - 14,
      top: y - 8,
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
    final r = cellRectMm(widget.template.grid, cell);
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
            final span = (c.col - cell.col + 1).clamp(1, widget.template.grid.cols);
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
            final span = (c.row - cell.row + 1).clamp(1, widget.template.grid.rows);
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
