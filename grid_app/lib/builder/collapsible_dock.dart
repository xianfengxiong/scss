import 'package:flutter/material.dart';

/// A desktop side panel: expanded it shows a titled column with [child];
/// collapsed it shrinks to a thin rail with just the expand chevron and the
/// title turned sideways, giving the canvas the width back.
class CollapsibleDock extends StatefulWidget {
  final String title;

  /// Which screen edge this dock sits on — decides the chevron direction.
  final bool onLeft;

  /// Panel width when expanded.
  final double width;

  final Widget child;

  const CollapsibleDock({
    super.key,
    required this.title,
    required this.onLeft,
    required this.width,
    required this.child,
  });

  @override
  State<CollapsibleDock> createState() => _CollapsibleDockState();
}

class _CollapsibleDockState extends State<CollapsibleDock> {
  bool _expanded = true;

  IconData get _chevron => widget.onLeft
      ? (_expanded ? Icons.chevron_left : Icons.chevron_right)
      : (_expanded ? Icons.chevron_right : Icons.chevron_left);

  @override
  Widget build(BuildContext context) {
    final toggle = IconButton(
      key: ValueKey('dock-toggle-${widget.title}'),
      icon: Icon(_chevron),
      tooltip: _expanded ? 'Collapse ${widget.title}' : widget.title,
      onPressed: () => setState(() => _expanded = !_expanded),
    );
    if (!_expanded) {
      return SizedBox(
        width: 40,
        child: Column(
          children: [
            toggle,
            const SizedBox(height: 8),
            RotatedBox(
              quarterTurns: widget.onLeft ? 3 : 1,
              child: Text(widget.title,
                  style: Theme.of(context).textTheme.labelMedium),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: widget.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!widget.onLeft) toggle,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(widget.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              if (widget.onLeft) toggle,
            ],
          ),
          const Divider(height: 1),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
