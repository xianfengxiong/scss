import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/fill/survey_name_dialog.dart';

/// Pumps a button that opens the dialog, taps it, and settles — leaving the
/// dialog open. The dialog's eventual result is delivered via [onResult]
/// (called only when the dialog closes), so tests assert on a captured
/// variable after they close the dialog themselves.
Future<void> _pumpOpener(WidgetTester tester, void Function(String?) onResult,
    {String initial = 'Init'}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (ctx) => TextButton(
        onPressed: () async {
          onResult(await promptForSurveyName(ctx,
              title: 'New survey', initial: initial));
        },
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('prefills initial and returns trimmed text on OK',
      (tester) async {
    String? result = 'sentinel';
    await _pumpOpener(tester, (r) => result = r, initial: 'Site A');
    expect(find.text('Site A'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), '  Site B  ');
    await tester.tap(find.byKey(const ValueKey('survey-name-ok')));
    await tester.pumpAndSettle();
    expect(result, 'Site B');
  });

  testWidgets('cancel returns null', (tester) async {
    String? result = 'sentinel';
    await _pumpOpener(tester, (r) => result = r);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('blank input disables OK', (tester) async {
    await _pumpOpener(tester, (_) {});
    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), '   ');
    await tester.pump();
    final ok = tester.widget<TextButton>(
        find.byKey(const ValueKey('survey-name-ok')));
    expect(ok.onPressed, isNull);
  });

  testWidgets('Enter/done submits like OK', (tester) async {
    String? result = 'sentinel';
    await _pumpOpener(tester, (r) => result = r);
    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), '  Site C  ');
    // The field's submit action — Enter on a physical keyboard, "done" on
    // the soft keyboard.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result, 'Site C');
  });

  testWidgets('Enter on blank input keeps the dialog open', (tester) async {
    String? result = 'sentinel';
    await _pumpOpener(tester, (r) => result = r);
    await tester.enterText(
        find.byKey(const ValueKey('survey-name-field')), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result, 'sentinel', reason: 'dialog must not close');
    expect(find.byKey(const ValueKey('survey-name-ok')), findsOneWidget);
  });
}
