import 'package:flutter/material.dart';

import '../controls/control_spec.dart';
import '../controls/registry.dart';
import '../services/platform_info.dart';

/// The registry's controls, as a horizontal strip (phone, above the canvas)
/// or a vertical list (desktop, docked left). Tapping one adds it to the
/// template; dragging places it on a specific cell. Touch needs long-press to
/// disambiguate from the list's scroll; a mouse drags instantly.
class ControlPalette extends StatelessWidget {
  final ControlRegistry registry;
  final void Function(ControlSpec spec) onPick;
  final Axis axis;

  const ControlPalette(
      {super.key,
      required this.registry,
      required this.onPick,
      this.axis = Axis.horizontal});

  @override
  Widget build(BuildContext context) {
    if (axis == Axis.vertical) {
      return ListView(
        padding: const EdgeInsets.all(8),
        children: [
          for (final spec in registry.all)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: _draggable(spec, _rowTile(spec)),
            ),
        ],
      );
    }
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          for (final spec in registry.all)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _draggable(spec, _tile(spec)),
            ),
        ],
      ),
    );
  }

  Widget _draggable(ControlSpec spec, Widget child) {
    final feedback = Material(
      color: Colors.transparent,
      child: Chip(
        avatar: Icon(spec.icon, size: 18),
        label: Text(spec.label),
      ),
    );
    return isDesktopPlatform
        ? Draggable<ControlSpec>(
            data: spec,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: feedback,
            child: child,
          )
        : LongPressDraggable<ControlSpec>(
            data: spec,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: feedback,
            child: child,
          );
  }

  /// Full-width row tile for the vertical (docked) palette.
  Widget _rowTile(ControlSpec spec) => InkWell(
        onTap: () => onPick(spec),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCFD8DC)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(spec.icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(spec.label,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      );

  Widget _tile(ControlSpec spec) => InkWell(
        onTap: () => onPick(spec),
        child: Container(
          width: 84,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCFD8DC)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(spec.icon, size: 22),
              const SizedBox(height: 2),
              Text(spec.label,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}
