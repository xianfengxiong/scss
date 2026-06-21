import 'package:flutter/material.dart';

import '../controls/control_spec.dart';
import '../controls/registry.dart';
import '../data/template_store.dart';
import '../grid/hit_test.dart';
import '../model/cell.dart';
import '../model/template.dart';
import 'cell_inspector.dart';
import 'control_palette.dart';
import 'editor_ops.dart';
import 'grid_canvas.dart';
import 'pdf_preview_screen.dart';

/// Tap-based template editor (Phase 1B-ii-a): add controls from the palette,
/// tap a cell to select, edit it in the inspector, change grid rows/cols.
/// Drag manipulation arrives in Phase 1B-ii-b.
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
  late Template _t = widget.template;
  String? _selectedId;
  int _seq = 0;

  String _newId(String type) => '${type}_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  void _commit(Template? candidate) {
    if (candidate == null || !isValid(candidate)) return;
    setState(() => _t = candidate);
  }

  void _addControl(ControlSpec spec) {
    final row = firstFreeRow(_t);
    if (row == null) return; // grid full
    final cell = Cell(
      id: _newId(spec.type),
      col: 0,
      row: row,
      colSpan: _t.grid.cols,
      type: spec.type,
      props: spec.defaultProps(),
    );
    final candidate = addCell(_t, cell);
    if (isValid(candidate)) {
      setState(() {
        _t = candidate;
        _selectedId = cell.id;
      });
    }
  }

  void _onCanvasTap(Offset localPos, double scale) {
    final xMm = localPos.dx / scale;
    final yMm = localPos.dy / scale;
    final coord = cellCoordAtMm(_t.grid, xMm, yMm);
    final hit = coord == null ? null : cellAtCoord(_t, coord.col, coord.row);
    setState(() => _selectedId = hit?.id);
  }

  Cell? get _selected {
    for (final c in _t.cells) {
      if (c.id == _selectedId) return c;
    }
    return null;
  }

  Future<void> _save() async {
    await widget.store.upsert(_t);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Template saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: Column(
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
      body: Column(
        children: [
          _gridControls(),
          ControlPalette(registry: widget.registry, onPick: _addControl),
          const Divider(height: 1),
          Expanded(child: _canvasArea()),
          if (selected != null)
            Material(
              elevation: 8,
              child: CellInspector(
                cell: selected,
                spec: widget.registry.specFor(selected.type)!,
                maxColSpan: _t.grid.cols,
                onPropsChanged: (props) => _commit(
                    updateCell(_t, selected.id, (c) => c.copyWith(props: props))),
                onColSpanChanged: (span) => _commit(updateCell(
                    _t, selected.id, (c) => c.copyWith(colSpan: span))),
                onDelete: () {
                  _commit(removeCell(_t, selected.id));
                  setState(() => _selectedId = null);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _gridControls() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Text('Cols'),
            _step(() => _commit(setCols(_t, _t.grid.cols - 1)),
                () => _commit(setCols(_t, _t.grid.cols + 1)), 'cols'),
            const SizedBox(width: 16),
            const Text('Rows'),
            _step(() => _commit(setRows(_t, _t.grid.rows - 1)),
                () => _commit(setRows(_t, _t.grid.rows + 1)), 'rows'),
          ],
        ),
      );

  Widget _step(VoidCallback dec, VoidCallback inc, String key) => Row(
        children: [
          IconButton(
              key: ValueKey('$key-dec'),
              icon: const Icon(Icons.remove),
              onPressed: dec),
          IconButton(
              key: ValueKey('$key-inc'),
              icon: const Icon(Icons.add),
              onPressed: inc),
        ],
      );

  Widget _canvasArea() => LayoutBuilder(
        builder: (context, constraints) {
          // The canvas width drives the scale; mirror GridCanvas's own math.
          const pad = 12.0;
          final canvasWidth = constraints.maxWidth - pad * 2;
          final scale = canvasWidth / _t.page.widthMm;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(pad),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _onCanvasTap(d.localPosition, scale),
                child: GridCanvas(
                  template: _t,
                  registry: widget.registry,
                  selectedId: _selectedId,
                ),
              ),
            ),
          );
        },
      );
}
