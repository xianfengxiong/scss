import 'package:flutter/material.dart';

import '../controls/control_spec.dart';
import '../l10n/app_localizations.dart';
import '../model/cell.dart';

/// Edits the selected cell: its control props (via the control's `propEditor`),
/// its width in columns (colSpan stepper), and a delete action.
///
/// Two hosts, two shapes:
/// - Phone (bottom overlay, default): starts collapsed as a thin header bar
///   (control name + expand chevron + delete) so the canvas and the cell's
///   resize handle stay visible; the expanded body is height-capped and
///   scrollable so a tall editor never covers the canvas.
/// - Desktop right dock ([docked]): the panel itself solves the space
///   problem, so the editor is always visible — no chevron, no height cap,
///   scrolling fills the dock.
class CellInspector extends StatefulWidget {
  final Cell cell;
  final ControlSpec spec;
  final int maxColSpan;
  final void Function(Map<String, dynamic> props) onPropsChanged;
  final void Function(int colSpan) onColSpanChanged;
  final VoidCallback onDelete;

  /// Desktop right-dock mode; see the class note.
  final bool docked;

  const CellInspector({
    super.key,
    required this.cell,
    required this.spec,
    required this.maxColSpan,
    required this.onPropsChanged,
    required this.onColSpanChanged,
    required this.onDelete,
    this.docked = false,
  });

  @override
  State<CellInspector> createState() => _CellInspectorState();
}

class _CellInspectorState extends State<CellInspector> {
  // Starts collapsed (docked): selecting/switching cells keeps it as-is so the
  // canvas + resize handle stay visible. Expand only to edit properties.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cell = widget.cell;
    final l10n = AppLocalizations.of(context)!;
    if (widget.docked) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.spec.label,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  key: const ValueKey('cell-delete'),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: l10n.delete,
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(child: _editorBody(cell)),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.spec.label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                key: const ValueKey('inspector-toggle'),
                icon: Icon(_expanded ? Icons.expand_more : Icons.expand_less),
                tooltip: _expanded ? l10n.collapse : l10n.expand,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              IconButton(
                key: const ValueKey('cell-delete'),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: l10n.delete,
                onPressed: widget.onDelete,
              ),
            ],
          ),
          if (_expanded)
            ConstrainedBox(
              // Cap the expanded body to 40% of the screen and scroll if a
              // control's editor is tall, so even expanded it never swallows
              // the canvas.
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: SingleChildScrollView(child: _editorBody(cell)),
            ),
        ],
      ),
    );
  }

  Widget _editorBody(Cell cell) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key by cell id so selecting a different control rebuilds
          // the editor subtree fresh — otherwise a TextFormField keeps
          // its stale text (initialValue only seeds the controller).
          KeyedSubtree(
            key: ValueKey('propeditor-${widget.cell.id}'),
            child: widget.spec.propEditor(cell, widget.onPropsChanged),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(AppLocalizations.of(context)!.widthLabel(cell.colSpan)),
              const Spacer(),
              IconButton(
                key: const ValueKey('colspan-dec'),
                icon: const Icon(Icons.remove),
                onPressed: cell.colSpan > 1
                    ? () => widget.onColSpanChanged(cell.colSpan - 1)
                    : null,
              ),
              IconButton(
                key: const ValueKey('colspan-inc'),
                icon: const Icon(Icons.add),
                onPressed: cell.col + cell.colSpan < widget.maxColSpan
                    ? () => widget.onColSpanChanged(cell.colSpan + 1)
                    : null,
              ),
            ],
          ),
        ],
      );
}
