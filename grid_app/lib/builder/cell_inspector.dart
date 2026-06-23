import 'package:flutter/material.dart';

import '../controls/control_spec.dart';
import '../model/cell.dart';

/// Edits the selected cell: its control props (via the control's `propEditor`),
/// its width in columns (colSpan stepper), and a delete action.
///
/// Docked + collapsible: starts collapsed as a thin header bar (control name +
/// expand chevron + delete) so the canvas and the cell's resize handle stay
/// visible. Tap the chevron to expand the property editor only when you want to
/// edit; it stays as you left it when switching cells. While expanded the body
/// is height-capped and scrollable so a tall editor never covers the canvas.
class CellInspector extends StatefulWidget {
  final Cell cell;
  final ControlSpec spec;
  final int maxColSpan;
  final void Function(Map<String, dynamic> props) onPropsChanged;
  final void Function(int colSpan) onColSpanChanged;
  final VoidCallback onDelete;

  const CellInspector({
    super.key,
    required this.cell,
    required this.spec,
    required this.maxColSpan,
    required this.onPropsChanged,
    required this.onColSpanChanged,
    required this.onDelete,
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
                tooltip: _expanded ? 'Collapse' : 'Expand',
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              IconButton(
                key: const ValueKey('cell-delete'),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete',
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Key by cell id so selecting a different control rebuilds
                    // the editor subtree fresh — otherwise a TextFormField keeps
                    // its stale text (initialValue only seeds the controller).
                    KeyedSubtree(
                      key: ValueKey('propeditor-${cell.id}'),
                      child:
                          widget.spec.propEditor(cell, widget.onPropsChanged),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Width: ${cell.colSpan}'),
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
                ),
              ),
            ),
        ],
      ),
    );
  }
}
