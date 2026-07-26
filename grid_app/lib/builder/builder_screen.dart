import 'package:flutter/material.dart';

import '../controls/control_spec.dart';
import '../controls/registry.dart';
import '../data/template_store.dart';
import '../fill/survey_name_dialog.dart';
import '../grid/grid_resize.dart';
import '../model/cell.dart';
import '../model/template.dart';
import '../services/platform_info.dart';
import 'canvas_metrics.dart';
import 'cell_inspector.dart';
import 'collapsible_dock.dart';
import 'control_palette.dart';
import 'editable_canvas.dart';
import 'editor_ops.dart';
import 'pdf_preview_screen.dart';

/// Template editor: add controls from the palette, tap a cell to select,
/// edit it in the inspector, change grid rows/cols, and drag cells/handles
/// directly on the canvas (Phase 1B-ii-b).
class BuilderScreen extends StatefulWidget {
  final Template template;
  final ControlRegistry registry;
  final TemplateStore store;

  const BuilderScreen({
    super.key,
    required this.template,
    required this.registry,
    required this.store,
  });

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  // Templates saved before the centering invariant existed open off-center;
  // normalize on entry so the canvas shows what the next save will persist.
  late Template _t = centerGridX(widget.template);
  String? _selectedId;
  int _seq = 0;

  String _newId(String type) => '${type}_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  // Give a value control a key that doesn't collide with existing cells.
  Cell _withUniqueKey(Cell c) {
    final key = c.props['key'];
    if (key is! String) return c;
    return c.copyWith(props: {...c.props, 'key': uniqueKey(_t, key)});
  }

  void _commit(Template? candidate) {
    if (candidate == null) return;
    final centered = centerGridX(candidate);
    if (!isValid(centered)) return;
    setState(() => _t = centered);
  }

  void _addControl(ControlSpec spec) {
    final pos = firstFreeCell(_t);
    if (pos == null) return; // grid full
    final free = freeRunWidth(_t, pos.col, pos.row);
    if (free < 1) return;
    _placeAt(spec, pos.col, pos.row, free);
  }

  void _placeDropped(ControlSpec spec, int col, int row) {
    if (cellAtCoord(_t, col, row) != null) return; // occupied
    final free = freeRunWidth(_t, col, row);
    if (free < 1) return;
    _placeAt(spec, col, row, free);
  }

  void _placeAt(ControlSpec spec, int col, int row, int free) {
    final wantCol = spec.defaultColSpan() ?? free;
    final colSpan = wantCol < free ? wantCol : free;
    var cell = _withUniqueKey(Cell(
      id: _newId(spec.type),
      col: col,
      row: row,
      colSpan: colSpan,
      type: spec.type,
      props: spec.defaultProps(),
    ));
    final want = spec.requiredRowSpan(cell);
    if (want != null) cell = cell.copyWith(rowSpan: want);
    final candidate = addCell(_t, cell);
    if (isValid(candidate)) {
      setState(() {
        _t = candidate;
        _selectedId = cell.id;
      });
    }
  }

  Cell? get _selected {
    for (final c in _t.cells) {
      if (c.id == _selectedId) return c;
    }
    return null;
  }

  Future<void> _save() async {
    _t = _t.copyWith(updatedAt: DateTime.now());
    await widget.store.upsert(_t);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Template saved.')));
    }
  }

  /// Renaming persists immediately (unlike layout edits, which wait for
  /// Save) — a name is list-facing metadata, not part of the canvas work in
  /// progress, so backing out without Save must not revert it.
  Future<void> _rename() async {
    final name = await promptForSurveyName(context,
        title: 'Rename template', initial: _t.name);
    if (name == null || !mounted) return;
    setState(
        () => _t = _t.copyWith(name: name, updatedAt: DateTime.now()));
    await widget.store.upsert(_t);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        // Desktop: the grid steppers share the title row (the window is wide
        // and it frees a whole toolbar row for the canvas). Phone: keep the
        // stacked title + separate controls row — the AppBar is too narrow.
        title: isDesktopPlatform
            ? Row(
                children: [
                  Flexible(
                      child: Text(_t.name, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 24),
                  _stepper('Cols', _t.grid.cols,
                      () => _commit(setCols(_t, _t.grid.cols - 1)),
                      () => _commit(setCols(_t, _t.grid.cols + 1)), 'cols'),
                  const SizedBox(width: 12),
                  _stepper('Rows', _t.grid.rows,
                      () => _commit(setRows(_t, _t.grid.rows - 1)),
                      () => _commit(setRows(_t, _t.grid.rows + 1)), 'rows'),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_t.name),
                  Text('${_t.grid.cols} × ${_t.grid.rows} grid',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.normal)),
                ],
              ),
        actions: [
          IconButton(
            key: const ValueKey('builder-rename'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename',
            onPressed: _rename,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Preview',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  PdfPreviewScreen(template: _t, registry: widget.registry),
            )),
          ),
          IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save',
              onPressed: _save),
        ],
      ),
      // Desktop has the width for IDE-style side docks; the phone keeps the
      // stacked layout (palette strip on top, inspector overlaying the
      // canvas bottom).
      body: isDesktopPlatform ? _desktopBody(selected) : _mobileBody(selected),
    );
  }

  Widget _mobileBody(Cell? selected) => Column(
        children: [
          _gridControls(),
          ControlPalette(registry: widget.registry, onPick: _addControl),
          const Divider(height: 1),
          // Canvas fills the remaining space; the inspector OVERLAYS its bottom
          // (a Stack, not a Column row) so selecting a cell doesn't shrink the
          // canvas and shift every drag coordinate.
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _canvasArea()),
                if (selected != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Material(
                      elevation: 8,
                      child: _inspector(selected, docked: false),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _desktopBody(Cell? selected) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CollapsibleDock(
            title: 'Controls',
            onLeft: true,
            width: 176,
            child: ControlPalette(
              registry: widget.registry,
              onPick: _addControl,
              axis: Axis.vertical,
            ),
          ),
          const VerticalDivider(width: 1),
          // Grid steppers live in the AppBar title row on desktop, so the
          // middle column is all canvas.
          Expanded(child: _canvasArea()),
          const VerticalDivider(width: 1),
          // Always present (fixed width) so selecting/deselecting never
          // resizes the canvas mid-drag.
          CollapsibleDock(
            title: 'Properties',
            onLeft: false,
            width: 280,
            child: selected == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('点击画布上的控件以编辑属性',
                          textAlign: TextAlign.center),
                    ),
                  )
                : _inspector(selected, docked: true),
          ),
        ],
      );

  Widget _inspector(Cell selected, {required bool docked}) => CellInspector(
        cell: selected,
        spec: widget.registry.specFor(selected.type)!,
        maxColSpan: _t.grid.cols,
        docked: docked,
        onPropsChanged: (props) => _commit(syncRowSpan(
            updateCell(_t, selected.id, (c) => c.copyWith(props: props)),
            selected.id,
            widget.registry)),
        onColSpanChanged: (span) => _commit(
            updateCell(_t, selected.id, (c) => c.copyWith(colSpan: span))),
        onDelete: () {
          _commit(removeCell(_t, selected.id));
          setState(() => _selectedId = null);
        },
      );

  Widget _gridControls() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            _stepper('Cols', _t.grid.cols,
                () => _commit(setCols(_t, _t.grid.cols - 1)),
                () => _commit(setCols(_t, _t.grid.cols + 1)), 'cols'),
            const SizedBox(width: 16),
            _stepper('Rows', _t.grid.rows,
                () => _commit(setRows(_t, _t.grid.rows - 1)),
                () => _commit(setRows(_t, _t.grid.rows + 1)), 'rows'),
          ],
        ),
      );

  /// `Label − N +` — compact enough for the AppBar title row.
  Widget _stepper(
          String label, int value, VoidCallback dec, VoidCallback inc,
          String key) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.normal)),
          IconButton(
              key: ValueKey('$key-dec'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove, size: 18),
              onPressed: dec),
          Text('$value',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
          IconButton(
              key: ValueKey('$key-inc'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add, size: 18),
              onPressed: inc),
        ],
      );

  // No scroll view: the canvas fits the available box (EditableCanvas scales to
  // fit width AND height), so a vertical scroll can't steal the move gesture.
  Widget _canvasArea() => Padding(
        padding: const EdgeInsets.all(kCanvasPad),
        child: Center(
          child: EditableCanvas(
            template: _t,
            registry: widget.registry,
            selectedId: _selectedId,
            onSelect: (id) => setState(() => _selectedId = id),
            onMove: (id, col, row) => _commit(moveCell(_t, id, col, row)),
            onSpan: (id, colSpan, rowSpan) => _commit(reconcileCell(
                setSpan(_t, id, colSpan, rowSpan), id, widget.registry)),
            onResizeCol: (boundary, deltaMm) => _commit(
                _t.copyWith(grid: resizeColBoundary(_t.grid, boundary, deltaMm))),
            onResizeRow: (boundary, deltaMm) => _commit(
                _t.copyWith(grid: resizeRowBoundary(_t.grid, boundary, deltaMm))),
            onDropControl: _placeDropped,
          ),
        ),
      );
}
