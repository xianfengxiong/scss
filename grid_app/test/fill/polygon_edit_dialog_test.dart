import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scss_grid/fill/polygon_edit_dialog.dart';
import 'package:scss_grid/l10n/app_localizations.dart';

/// Host widget that opens [PolygonEditDialog] and stores the popped result.
class _Host extends StatefulWidget {
  final String initialLabel;
  final int initialColor;
  final double initialOpacity;
  const _Host(
      {this.initialLabel = '',
      this.initialColor = 0xFFC107,
      this.initialOpacity = 0.35});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  PolygonEditResult? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(builder: (ctx) {
        return ElevatedButton(
          key: const Key('open'),
          onPressed: () async {
            final r = await showDialog<PolygonEditResult>(
              context: ctx,
              builder: (_) => PolygonEditDialog(
                initialLabel: widget.initialLabel,
                initialColor: widget.initialColor,
                initialOpacity: widget.initialOpacity,
              ),
            );
            setState(() => result = r);
          },
          child: const Text('Open'),
        );
      }),
    );
  }
}

void main() {
  Future<_HostState> open(WidgetTester tester,
      {String label = '', int color = 0xFFC107, double opacity = 0.35}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _Host(
          initialLabel: label, initialColor: color, initialOpacity: opacity),
    ));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    return tester.state<_HostState>(find.byType(_Host));
  }

  group('PolygonEditDialog', () {
    testWidgets('Cancel pops action=cancel with the current style',
        (tester) async {
      final host = await open(tester, label: 'zone');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(host.result,
          (action: 'cancel', label: '', color: 0xFFC107, opacity: 0.35));
    });

    testWidgets('Delete pops action=delete', (tester) async {
      final host = await open(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(host.result?.action, 'delete');
    });

    testWidgets('OK pops the trimmed label and untouched defaults',
        (tester) async {
      final host = await open(tester);
      await tester.enterText(find.byType(TextField), '  Site A  ');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(host.result,
          (action: 'ok', label: 'Site A', color: 0xFFC107, opacity: 0.35));
    });

    testWidgets('initial values pre-fill: label text, checked swatch, %',
        (tester) async {
      await open(tester, label: 'existing', color: 0x2196F3, opacity: 0.6);
      expect(find.widgetWithText(TextField, 'existing'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('poly-color-2196f3')),
              matching: find.byIcon(Icons.check)),
          findsOneWidget);
      expect(find.textContaining('60%'), findsOneWidget);
    });

    testWidgets('tapping a swatch changes the colour popped with OK',
        (tester) async {
      final host = await open(tester);
      await tester.tap(find.byKey(const ValueKey('poly-color-4caf50')));
      await tester.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('poly-color-4caf50')),
              matching: find.byIcon(Icons.check)),
          findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(host.result?.color, 0x4CAF50);
    });

    testWidgets('moving the slider changes opacity and the % readout',
        (tester) async {
      final host = await open(tester);
      final slider =
          tester.widget<Slider>(find.byKey(const ValueKey('poly-opacity')));
      slider.onChanged!(0.8);
      await tester.pumpAndSettle();
      expect(find.textContaining('80%'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(host.result?.opacity, 0.8);
    });

    testWidgets('palette exposes every colour as a tappable swatch',
        (tester) async {
      await open(tester);
      for (final c in polygonPalette) {
        expect(
            find.byKey(
                ValueKey('poly-color-${c.toRadixString(16).padLeft(6, '0')}')),
            findsOneWidget);
      }
    });
  });
}
