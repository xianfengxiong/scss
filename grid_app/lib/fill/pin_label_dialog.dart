import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'pin_icons.dart';

/// A dialog to edit/delete a map pin: label, marker icon, and — for device
/// icons — the heading the device points at (cameras are aimed at a junction).
/// The classic 'pin' glyph never rotates, so its slider is hidden. Owns its
/// [TextEditingController] and disposes it in [State.dispose] (called only
/// after the route is fully removed) — disposing it synchronously after
/// showDialog returns would corrupt the element lifecycle while the route is
/// still animating out.
/// Pops `(action, label, icon, rotation)` where action is
/// 'delete' | 'cancel' | 'ok'.
class PinLabelDialog extends StatefulWidget {
  final String initialLabel;
  final String initialIcon;
  final double initialRotation;
  const PinLabelDialog({
    super.key,
    required this.initialLabel,
    this.initialIcon = 'pin',
    this.initialRotation = 0,
  });

  @override
  State<PinLabelDialog> createState() => _PinLabelDialogState();
}

class _PinLabelDialogState extends State<PinLabelDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialLabel);
  late String _icon = widget.initialIcon;
  late double _rotation = widget.initialRotation;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.pinTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.pinLabelOptional),
          ),
          const SizedBox(height: 12),
          Wrap(
            children: [
              for (final entry in pinIconChoices.entries)
                IconButton(
                  key: ValueKey('pin-icon-${entry.key}'),
                  // The selected device icon previews its heading live.
                  icon: Transform.rotate(
                    angle: (_icon == entry.key && entry.key != 'pin')
                        ? _rotation * math.pi / 180
                        : 0,
                    child: Icon(entry.value),
                  ),
                  isSelected: _icon == entry.key,
                  style: IconButton.styleFrom(
                    backgroundColor: _icon == entry.key
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : null,
                    foregroundColor: _icon == entry.key ? Colors.red : null,
                  ),
                  onPressed: () => setState(() => _icon = entry.key),
                ),
            ],
          ),
          if (_icon != 'pin') ...[
            const SizedBox(height: 4),
            Text('${l10n.pinHeading} ${_rotation.round()}°',
                style: Theme.of(context).textTheme.bodySmall),
            Slider(
              key: const ValueKey('pin-rotation'),
              value: _rotation,
              min: 0,
              max: 355,
              divisions: 71, // 5° steps
              onChanged: (v) => setState(() => _rotation = v),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () =>
                Navigator.pop(context, ('delete', '', _icon, _rotation)),
            child: Text(l10n.delete,
                style: const TextStyle(color: Colors.red))),
        TextButton(
            onPressed: () =>
                Navigator.pop(context, ('cancel', '', _icon, _rotation)),
            child: Text(l10n.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(
                context, ('ok', _ctrl.text.trim(), _icon, _rotation)),
            child: Text(l10n.ok)),
      ],
    );
  }
}
