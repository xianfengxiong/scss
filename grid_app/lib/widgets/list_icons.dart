import 'package:flutter/material.dart';

/// Leading icons that tell the two row types apart at a glance: a template
/// is the designed grid (dashboard tile on the primary container), a survey
/// is the filled-in form (clipboard on the tertiary container). Same pair
/// everywhere a row of that type appears, so the shape+color reads as the
/// type without reading the text.
Widget templateListIcon(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return _badge(scheme.primaryContainer,
      Icon(Icons.space_dashboard_outlined, color: scheme.onPrimaryContainer));
}

Widget surveyListIcon(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return _badge(scheme.tertiaryContainer,
      Icon(Icons.assignment_outlined, color: scheme.onTertiaryContainer));
}

Widget _badge(Color background, Icon icon) => Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconTheme.merge(
          data: const IconThemeData(size: 22), child: Center(child: icon)),
    );
