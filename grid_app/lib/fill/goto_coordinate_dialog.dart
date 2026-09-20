import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../l10n/app_localizations.dart';
import 'latlon_parse.dart';

/// Type or paste a coordinate pair to jump the map there — for editing a
/// diagram away from the site, when the GPS button is no help. Pre-filled
/// with the current map centre (select-all, so a paste replaces it; also
/// handy for copying the centre out). Pops a [LatLng], or null on cancel.
class GoToCoordinateDialog extends StatefulWidget {
  final LatLng? initial;
  const GoToCoordinateDialog({super.key, this.initial});

  @override
  State<GoToCoordinateDialog> createState() => _GoToCoordinateDialogState();
}

class _GoToCoordinateDialogState extends State<GoToCoordinateDialog> {
  late final TextEditingController _ctrl;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    final text = c == null
        ? ''
        : '${c.latitude.toStringAsFixed(6)}, ${c.longitude.toStringAsFixed(6)}';
    _ctrl = TextEditingController(text: text)
      ..selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final r = parseLatLon(_ctrl.text);
    if (r == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, LatLng(r.lat, r.lon));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.goToCoordinates),
      content: TextField(
        key: const ValueKey('goto-input'),
        controller: _ctrl,
        autofocus: true,
        // Text keyboard: numeric pads lack the comma and N/S/E/W letters.
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          labelText: l10n.coordinatesLabel,
          hintText: '25.2048, 55.2708',
          errorText: _invalid ? l10n.coordinatesInvalid : null,
        ),
        onChanged: (_) {
          if (_invalid) setState(() => _invalid = false);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
            key: const ValueKey('goto-go'),
            onPressed: _submit,
            child: Text(l10n.goTo)),
      ],
    );
  }
}
