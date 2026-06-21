import 'package:flutter/material.dart';

import '../controls/control_spec.dart';
import '../model/cell.dart';

/// Edits the selected cell: its control props (via the control's `propEditor`),
/// its width in columns (colSpan stepper), and a delete action. Move, rowSpan
/// and drag come in Phase 1B-ii-b.
class CellInspector extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(spec.label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                key: const ValueKey('cell-delete'),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
            ],
          ),
          spec.propEditor(cell, onPropsChanged),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Width: ${cell.colSpan}'),
              const Spacer(),
              IconButton(
                key: const ValueKey('colspan-dec'),
                icon: const Icon(Icons.remove),
                onPressed: cell.colSpan > 1
                    ? () => onColSpanChanged(cell.colSpan - 1)
                    : null,
              ),
              IconButton(
                key: const ValueKey('colspan-inc'),
                icon: const Icon(Icons.add),
                onPressed: cell.col + cell.colSpan < maxColSpan
                    ? () => onColSpanChanged(cell.colSpan + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
