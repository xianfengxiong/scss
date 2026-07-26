import 'package:flutter/material.dart';

import '../controls/control_spec.dart';
import '../controls/registry.dart';
import '../services/platform_info.dart';

/// A horizontal strip of the registry's controls. Tapping one adds it to the
/// template; dragging places it on a specific cell. Touch needs long-press to
/// disambiguate from the list's horizontal scroll; a mouse drags instantly.
class ControlPalette extends StatelessWidget {
  final ControlRegistry registry;
  final void Function(ControlSpec spec) onPick;

  const ControlPalette(
      {super.key, required this.registry, required this.onPick});

  @override
  Widget build(BuildContext context) {
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
