import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'pin_icons.dart';

/// A dialog to edit/delete a map pin's label and pick its marker icon.
/// Heading is NOT edited here — after OK on a device icon the map enters
/// aim mode (drag the on-map handle), which is what-you-see-is-what-you-get.
/// Owns its [TextEditingController] and disposes it in [State.dispose]
/// (called only after the route is fully removed) — disposing it synchronously
/// after showDialog returns would corrupt the element lifecycle while the
/// route is still animating out.
/// Pops `(action, label, icon)` where action is 'delete' | 'cancel' | 'ok'.
class PinLabelDialog extends StatefulWidget {
  final String initialLabel;
  final String initialIcon;
  const PinLabelDialog(
      {super.key, required this.initialLabel, this.initialIcon = 'pin'});

  @override
  State<PinLabelDialog> createState() => _PinLabelDialogState();
}

class _PinLabelDialogState extends State<PinLabelDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialLabel);
  late String _icon = widget.initialIcon;

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
                  icon: Icon(entry.value),
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
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, ('delete', '', _icon)),
            child: Text(l10n.delete,
                style: const TextStyle(color: Colors.red))),
        TextButton(
            onPressed: () => Navigator.pop(context, ('cancel', '', _icon)),
            child: Text(l10n.cancel)),
        FilledButton(
            onPressed: () =>
                Navigator.pop(context, ('ok', _ctrl.text.trim(), _icon)),
            child: Text(l10n.ok)),
      ],
    );
  }
}
