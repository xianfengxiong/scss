import 'package:flutter/material.dart';

/// Prompts for a survey name. Returns the trimmed name, or null on cancel.
Future<String?> promptForSurveyName(BuildContext context,
        {required String title, required String initial}) =>
    showDialog<String>(
      context: context,
      builder: (_) => SurveyNameDialog(title: title, initial: initial),
    );

/// Owns its TextEditingController (created in state, disposed in state) so the
/// controller outlives the route's exit animation — see PinLabelDialog for the
/// crash this avoids.
class SurveyNameDialog extends StatefulWidget {
  final String title;
  final String initial;

  const SurveyNameDialog(
      {super.key, required this.title, required this.initial});

  @override
  State<SurveyNameDialog> createState() => _SurveyNameDialogState();
}

class _SurveyNameDialogState extends State<SurveyNameDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Shared by the OK button and the field's submit action (Enter on a
  // physical keyboard, "done" on the soft keyboard). Reads the live
  // controller value (not a build snapshot) — see the OK button note.
  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('survey-name-field'),
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _ctrl,
          builder: (_, value, __) => TextButton(
            key: const ValueKey('survey-name-ok'),
            onPressed: value.text.trim().isEmpty
                ? null
                // Read the live controller value (not the `value` snapshot
                // captured by this build) because tests can tap this button
                // in the same synchronous phase as an enterText() that
                // hasn't triggered a rebuild yet.
                : _submit,
            child: const Text('OK'),
          ),
        ),
      ],
    );
  }
}
