import 'package:flutter/material.dart';

import '../controls/control_spec.dart';
import '../controls/registry.dart';
import '../data/template_store.dart';
import '../fill/survey_name_dialog.dart';
import '../grid/grid_resize.dart';
import '../l10n/app_localizations.dart';
import '../model/cell.dart';
import '../model/template.dart';
import '../services/platform_info.dart';
import '../widgets/page_turn_switcher.dart';
import 'canvas_metrics.dart';
import 'cell_inspector.dart';
import 'collapsible_dock.dart';
import 'control_palette.dart';
import 'editable_canvas.dart';
import 'editor_ops.dart';
import 'pdf_preview_screen.dart';

/// Template editor: add controls from the palette, tap a cell to select,
/// edit it in the inspector, change grid rows/cols, and drag cells/handles
/// directly on the canvas. Multi-page: the canvas edits one page at a time;
/// the page navigator switches, adds (inheriting the current page's grid,
/// empty of controls) and deletes pages.
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
  late Template _t = _centerAllPages(widget.template);
  int _pageIndex = 0;
  String? _selectedId;
  int _seq = 0;

  // Which way the last page change travelled, for the slide animation.
  int _turnDir = 1;

  static Template _centerAllPages(Template t) {
    var out = t;
    for (var i = 0; i < t.pages.length; i++) {
      out = out.withPage(i, centerGridX(out.pages[i], out.page));
    }
    return out;
  }

  TemplatePage get _page => _t.pages[_pageIndex];

  String _newId(String type) => '${type}_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  // Give a value control a key that doesn't collide with existing cells
  // (across ALL pages — survey answers are one map for the whole template).
  Cell _withUniqueKey(Cell c) {
    final key = c.props['key'];
    if (key is! String) return c;
    return c.copyWith(props: {...c.props, 'key': uniqueKey(_t, key)});
  }

  /// Commit an edit to the current page: recenter, then accept only if the
  /// whole template stays valid.
  void _commitPage(TemplatePage? candidate) {
    if (candidate == null) return;
    final next = _t.withPage(_pageIndex, centerGridX(candidate, _t.page));
    if (!isValid(next)) return;
    setState(() => _t = next);
  }

  void _addControl(ControlSpec spec) {
    final pos = firstFreeCell(_page);
    if (pos == null) return; // grid full
    final free = freeRunWidth(_page, pos.col, pos.row);
    if (free < 1) return;
    _placeAt(spec, pos.col, pos.row, free);
  }

  void _placeDropped(ControlSpec spec, int col, int row) {
    if (cellAtCoord(_page, col, row) != null) return; // occupied
    final free = freeRunWidth(_page, col, row);
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
    final next = _t.withPage(_pageIndex, addCell(_page, cell));
    if (isValid(next)) {
      setState(() {
        _t = next;
        _selectedId = cell.id;
      });
    }
  }

  Cell? get _selected {
    for (final c in _page.cells) {
      if (c.id == _selectedId) return c;
    }
    return null;
  }

  Future<void> _save() async {
    _t = _t.copyWith(updatedAt: DateTime.now());
    await widget.store.upsert(_t);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.templateSaved)));
    }
  }

  /// Renaming persists immediately (unlike layout edits, which wait for
  /// Save) — a name is list-facing metadata, not part of the canvas work in
  /// progress, so backing out without Save must not revert it.
  Future<void> _rename() async {
    final name = await promptForSurveyName(context,
        title: AppLocalizations.of(context)!.renameTemplate, initial: _t.name);
    if (name == null || !mounted) return;
    setState(
        () => _t = _t.copyWith(name: name, updatedAt: DateTime.now()));
    await widget.store.upsert(_t);
  }

  void _goToPage(int index) => setState(() {
        final target = index.clamp(0, _t.pages.length - 1);
        _turnDir = target >= _pageIndex ? 1 : -1;
        _pageIndex = target;
        _selectedId = null;
      });

  void _addPage() => setState(() {
        _t = addPageAfter(_t, _pageIndex);
        _turnDir = 1;
        _pageIndex++;
        _selectedId = null;
      });

  Future<void> _deletePage() async {
    final removed = removePage(_t, _pageIndex);
    if (removed == null) return; // last page — button is disabled anyway
    if (_page.cells.isNotEmpty) {
      final l10n = AppLocalizations.of(context)!;
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.deletePageTitle(_pageIndex + 1)),
          content: Text(l10n.deletePageContent(_page.cells.length)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.delete)),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() {
      _t = removed;
      _turnDir = -1;
      _pageIndex = _pageIndex.clamp(0, _t.pages.length - 1);
      _selectedId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        // Desktop: the grid steppers and page navigator share the title row
        // (the window is wide and it frees a toolbar row for the canvas).
        // Phone: stacked title; steppers + page navigator on their own row.
        title: isDesktopPlatform
            ? Row(
                children: [
                  Flexible(
                      child: Text(_t.name, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 24),
                  _stepper(l10n.cols, _page.grid.cols,
                      () => _commitPage(setCols(_page, _t.page, _page.grid.cols - 1)),
                      () => _commitPage(setCols(_page, _t.page, _page.grid.cols + 1)), 'cols'),
                  const SizedBox(width: 12),
                  _stepper(l10n.rows, _page.grid.rows,
                      () => _commitPage(setRows(_page, _t.page, _page.grid.rows - 1)),
                      () => _commitPage(setRows(_page, _t.page, _page.grid.rows + 1)), 'rows'),
                  const SizedBox(width: 12),
                  _pageNav(),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_t.name),
                  Text(
                      l10n.builderSubtitle(
                          _page.grid.cols, _page.grid.rows, _t.pages.length),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.normal)),
                ],
              ),
        actions: [
          IconButton(
            key: const ValueKey('builder-rename'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.rename,
            onPressed: _rename,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.preview,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  PdfPreviewScreen(template: _t, registry: widget.registry),
            )),
          ),
          IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: l10n.save,
              onPressed: _save),
        ],
      ),
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

  Widget _desktopBody(Cell? selected) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollapsibleDock(
          title: l10n.controlsDock,
          onLeft: true,
          width: 176,
          child: ControlPalette(
            registry: widget.registry,
            onPick: _addControl,
            axis: Axis.vertical,
          ),
        ),
        const VerticalDivider(width: 1),
        // Grid steppers + page navigator live in the AppBar title row on
        // desktop, so the middle column is all canvas.
        Expanded(child: _canvasArea()),
        const VerticalDivider(width: 1),
        // Always present (fixed width) so selecting/deselecting never
        // resizes the canvas mid-drag.
        CollapsibleDock(
          title: l10n.propertiesDock,
          onLeft: false,
          width: 280,
          child: selected == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.selectControlHint,
                        textAlign: TextAlign.center),
                  ),
                )
              : _inspector(selected, docked: true),
        ),
      ],
    );
  }

  Widget _inspector(Cell selected, {required bool docked}) => CellInspector(
        cell: selected,
        spec: widget.registry.specFor(selected.type)!,
        maxColSpan: _page.grid.cols,
        docked: docked,
        onPropsChanged: (props) => _commitPage(syncRowSpan(
            updateCell(_page, selected.id, (c) => c.copyWith(props: props)),
            selected.id,
            widget.registry)),
        onColSpanChanged: (span) => _commitPage(
            updateCell(_page, selected.id, (c) => c.copyWith(colSpan: span))),
        onDelete: () {
          _commitPage(removeCell(_page, selected.id));
          setState(() => _selectedId = null);
        },
      );

  /// Phone: steppers + page navigator on one row above the palette. FittedBox
  /// keeps a narrow screen from overflowing.
  Widget _gridControls() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            _stepper(l10n.cols, _page.grid.cols,
                () => _commitPage(setCols(_page, _t.page, _page.grid.cols - 1)),
                () => _commitPage(setCols(_page, _t.page, _page.grid.cols + 1)), 'cols'),
            const SizedBox(width: 16),
            _stepper(l10n.rows, _page.grid.rows,
                () => _commitPage(setRows(_page, _t.page, _page.grid.rows - 1)),
                () => _commitPage(setRows(_page, _t.page, _page.grid.rows + 1)), 'rows'),
            const SizedBox(width: 16),
            _pageNav(),
          ],
        ),
      ),
    );
  }

  /// `‹ 1/3 ›  +  🗑` — switch, append (inherits this page's grid, no
  /// controls), delete (disabled on the last page; confirms if not empty).
  Widget _pageNav() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('page-prev'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left, size: 20),
          tooltip: l10n.previousPage,
          onPressed: _pageIndex > 0 ? () => _goToPage(_pageIndex - 1) : null,
        ),
        Text('${_pageIndex + 1}/${_t.pages.length}',
            key: const ValueKey('page-indicator'),
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
        IconButton(
          key: const ValueKey('page-next'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right, size: 20),
          tooltip: l10n.nextPage,
          onPressed: _pageIndex < _t.pages.length - 1
              ? () => _goToPage(_pageIndex + 1)
              : null,
        ),
        IconButton(
          key: const ValueKey('page-add'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.post_add, size: 20),
          tooltip: l10n.addPageTooltip,
          onPressed: _addPage,
        ),
        IconButton(
          key: const ValueKey('page-delete'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete_sweep_outlined, size: 20),
          tooltip: l10n.deletePageTooltip,
          onPressed: _t.pages.length > 1 ? _deletePage : null,
        ),
      ],
    );
  }

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
          child: PageTurnSwitcher(
            pageIndex: _pageIndex,
            direction: _turnDir,
            child: EditableCanvas(
            template: _t,
            pageIndex: _pageIndex,
            registry: widget.registry,
            selectedId: _selectedId,
            onSelect: (id) => setState(() => _selectedId = id),
            onMove: (id, col, row) => _commitPage(moveCell(_page, id, col, row)),
            onSpan: (id, colSpan, rowSpan) => _commitPage(reconcileCell(
                setSpan(_page, id, colSpan, rowSpan), id, widget.registry)),
            onResizeCol: (boundary, deltaMm) => _commitPage(_page.copyWith(
                grid: resizeColBoundary(_page.grid, boundary, deltaMm))),
            onResizeRow: (boundary, deltaMm) => _commitPage(_page.copyWith(
                grid: resizeRowBoundary(_page.grid, boundary, deltaMm))),
              onDropControl: _placeDropped,
              // Horizontal swipe on an empty cell turns the page.
              onSwipePage: (dir) => _goToPage(_pageIndex + dir),
            ),
          ),
        ),
      );
}
