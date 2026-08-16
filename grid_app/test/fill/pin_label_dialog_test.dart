import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scss_grid/fill/pin_label_dialog.dart';
import 'package:scss_grid/l10n/app_localizations.dart';

/// Host widget that pops open [PinLabelDialog] and stores the returned result.
class _Host extends StatefulWidget {
  final String initialLabel;
  final String initialIcon;
  const _Host({required this.initialLabel, this.initialIcon = 'pin'});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  (String, String, String)? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('result:${result?.$1 ?? '–'}/${result?.$2 ?? '–'}'),
          Builder(builder: (ctx) {
            return ElevatedButton(
              key: const Key('open'),
              onPressed: () async {
                final r = await showDialog<(String, String, String)>(
                  context: ctx,
                  builder: (_) => PinLabelDialog(
                      initialLabel: widget.initialLabel,
                      initialIcon: widget.initialIcon),
                );
                setState(() => result = r);
              },
              child: const Text('Open'),
            );
          }),
        ],
      ),
    );
  }
}

void main() {
  group('PinLabelDialog', () {
    Future<void> open(WidgetTester tester,
        {String initial = '', String icon = 'pin'}) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _Host(initialLabel: initial, initialIcon: icon),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
    }

    testWidgets('Cancel button pops (cancel, "", icon)', (tester) async {
      await open(tester, initial: 'hello');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final state = tester.state<_HostState>(find.byType(_Host));
      expect(state.result, equals(('cancel', '', 'pin')));
    });

    testWidgets('Delete button pops (delete, "", icon)', (tester) async {
      await open(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      final state = tester.state<_HostState>(find.byType(_Host));
      expect(state.result, equals(('delete', '', 'pin')));
    });

    testWidgets('OK button pops (ok, trimmed label, icon)', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), '  pole 7  ');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final state = tester.state<_HostState>(find.byType(_Host));
      expect(state.result, equals(('ok', 'pole 7', 'pin')));
    });

    testWidgets('picking the camera icon pops it with OK', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('pin-icon-camera')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final state = tester.state<_HostState>(find.byType(_Host));
      expect(state.result, equals(('ok', '', 'camera')));
    });

    testWidgets('initialIcon pre-selects; unchanged when only label edited',
        (tester) async {
      await open(tester, icon: 'bolt');
      await tester.enterText(find.byType(TextField), 'P9');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final state = tester.state<_HostState>(find.byType(_Host));
      expect(state.result, equals(('ok', 'P9', 'bolt')));
    });

    testWidgets('initialLabel pre-fills the text field', (tester) async {
      await open(tester, initial: 'existing');
      expect(find.widgetWithText(TextField, 'existing'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    /// KEY REGRESSION GUARD: after Delete, pumpAndSettle lets the route
    /// exit-animation finish and the sub-tree tear down. If the controller
    /// were disposed synchronously after showDialog() returned (the old bug),
    /// the InheritedElement.debugDeactivated assertion would fire here.
    testWidgets(
        'no exception after Delete — controller lifecycle regression guard',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle(); // route animates out; sub-tree is unmounted
      expect(tester.takeException(), isNull);
    });
  });
}
