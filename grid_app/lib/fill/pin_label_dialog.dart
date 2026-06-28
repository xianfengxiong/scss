import 'package:flutter/material.dart';

/// A dialog to edit/delete a map pin's label. Owns its [TextEditingController]
/// and disposes it in [State.dispose] (called only after the route is fully
/// removed) — disposing it synchronously after showDialog returns would corrupt
/// the element lifecycle while the route is still animating out.
/// Pops `(action, label)` where action is 'delete' | 'cancel' | 'ok'.
class PinLabelDialog extends StatefulWidget {
  final String initialLabel;
  const PinLabelDialog({super.key, required this.initialLabel});

  @override
  State<PinLabelDialog> createState() => _PinLabelDialogState();
}

class _PinLabelDialogState extends State<PinLabelDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialLabel);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Pin'),
        content: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Label (optional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, ('delete', '')),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
          TextButton(
              onPressed: () => Navigator.pop(context, ('cancel', '')),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, ('ok', _ctrl.text.trim())),
              child: const Text('OK')),
        ],
      );
}
