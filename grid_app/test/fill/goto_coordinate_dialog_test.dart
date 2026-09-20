import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'package:scss_grid/fill/goto_coordinate_dialog.dart';
import 'package:scss_grid/l10n/app_localizations.dart';

class _Host extends StatefulWidget {
  final LatLng? initial;
  const _Host({this.initial});
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  LatLng? result;
  bool popped = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            key: const Key('open'),
            onPressed: () async {
              final r = await showDialog<LatLng>(
                  context: ctx,
                  builder: (_) =>
                      GoToCoordinateDialog(initial: widget.initial));
              setState(() {
                result = r;
                popped = true;
              });
            },
            child: const Text('Open'),
          ),
        ),
      );
}

void main() {
  Future<_HostState> open(WidgetTester tester, {LatLng? initial}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _Host(initial: initial),
    ));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    return tester.state<_HostState>(find.byType(_Host));
  }

  testWidgets('pre-fills the current centre to 6 decimals', (tester) async {
    await open(tester, initial: const LatLng(25.20480123, 55.27081));
    expect(
        find.widgetWithText(TextField, '25.204801, 55.270810'), findsOneWidget);
  });

  testWidgets('Go pops the parsed LatLng', (tester) async {
    final host = await open(tester);
    await tester.enterText(
        find.byKey(const ValueKey('goto-input')), '33.9249 S, 18.4241 E');
    await tester.tap(find.byKey(const ValueKey('goto-go')));
    await tester.pumpAndSettle();
    expect(host.popped, isTrue);
    expect(host.result, const LatLng(-33.9249, 18.4241));
  });

  testWidgets('invalid input shows an error and stays open; typing clears it',
      (tester) async {
    final host = await open(tester);
    await tester.enterText(find.byKey(const ValueKey('goto-input')), 'nope');
    await tester.tap(find.byKey(const ValueKey('goto-go')));
    await tester.pumpAndSettle();
    expect(host.popped, isFalse);
    expect(find.text('Enter "latitude, longitude" in decimal degrees or DMS'),
        findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('goto-input')), '1, 2');
    await tester.pump();
    expect(find.text('Enter "latitude, longitude" in decimal degrees or DMS'),
        findsNothing);
  });

  testWidgets('Cancel pops null', (tester) async {
    final host = await open(tester, initial: const LatLng(1, 2));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(host.popped, isTrue);
    expect(host.result, isNull);
  });
}
