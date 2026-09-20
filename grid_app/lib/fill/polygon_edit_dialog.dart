import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../model/map_polygon.dart';

/// Fill colours offered for polygons (0xRRGGBB). A fixed palette rather than
/// a colour picker: quick to tap on a phone, and zones stay visually
/// consistent across surveys. The first entry is [MapPolygon.defaultColor].
const List<int> polygonPalette = [
  0xFFC107, // amber
  0xF44336, // red
  0xFF9800, // orange
  0xFFEB3B, // yellow
  0x4CAF50, // green
  0x00BCD4, // cyan
  0x2196F3, // blue
  0x9C27B0, // purple
  0xE91E63, // pink
  0xFFFFFF, // white
];

/// What the dialog pops; `action` is 'delete' | 'cancel' | 'ok'.
typedef PolygonEditResult = ({
  String action,
  String label,
  int color,
  double opacity,
});

/// Opaque [Color] for a 0xRRGGBB polygon colour.
Color polygonColor(int rgb) => Color(0xFF000000 | (rgb & 0xFFFFFF));

/// Edit a polygon's name, fill colour and fill opacity, or delete it. Owns
/// its [TextEditingController] and disposes it in [State.dispose] (see
/// PinLabelDialog for why not right after showDialog returns).
class PolygonEditDialog extends StatefulWidget {
  final String initialLabel;
  final int initialColor;
  final double initialOpacity;

  const PolygonEditDialog({
    super.key,
    this.initialLabel = '',
    this.initialColor = MapPolygon.defaultColor,
    this.initialOpacity = MapPolygon.defaultOpacity,
  });

  @override
  State<PolygonEditDialog> createState() => _PolygonEditDialogState();
}

class _PolygonEditDialogState extends State<PolygonEditDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialLabel);
  late int _color = widget.initialColor;
  late double _opacity = widget.initialOpacity;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  PolygonEditResult _result(String action, {String label = ''}) =>
      (action: action, label: label, color: _color, opacity: _opacity);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      title: Text(l10n.polygonTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.pinLabelOptional),
            ),
            const SizedBox(height: 16),
            Text(l10n.fillColor, style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in polygonPalette)
                  InkWell(
                    key: ValueKey(
                        'poly-color-${c.toRadixString(16).padLeft(6, '0')}'),
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: polygonColor(c),
                        border: Border.all(
                          color: _color == c
                              ? scheme.onSurface
                              : scheme.outlineVariant,
                          width: _color == c ? 3 : 1,
                        ),
                      ),
                      child: _color == c
                          ? Icon(Icons.check,
                              size: 18,
                              color:
                                  c == 0xFFFFFF ? Colors.black : Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.fillOpacity((_opacity * 100).round()),
                style: theme.textTheme.labelMedium),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    key: const ValueKey('poly-opacity'),
                    value: _opacity,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    onChanged: (v) => setState(() => _opacity = v),
                  ),
                ),
                // Live swatch: fill at the chosen opacity, solid outline —
                // exactly how the polygon renders on the map.
                Container(
                  width: 40,
                  height: 28,
                  decoration: BoxDecoration(
                    color: polygonColor(_color).withValues(alpha: _opacity),
                    border: Border.all(color: polygonColor(_color), width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, _result('delete')),
            child: Text(l10n.delete,
                style: const TextStyle(color: Colors.red))),
        TextButton(
            onPressed: () => Navigator.pop(context, _result('cancel')),
            child: Text(l10n.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(
                context, _result('ok', label: _ctrl.text.trim())),
            child: Text(l10n.ok)),
      ],
    );
  }
}
