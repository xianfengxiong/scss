import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scss_grid/l10n/app_localizations.dart';
import 'package:scss_grid/widgets/data_dir_notice.dart';

void main() {
  testWidgets('shows both paths once after first frame; OK dismisses',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DataDirNotice(
        portableDir: r'D:\SCSS Survey\userdata',
        actualDir: r'C:\Users\me\AppData\Roaming\com.example\scss_grid',
        child: Scaffold(body: Text('home')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining(r'D:\SCSS Survey\userdata'), findsOneWidget);
    expect(find.textContaining(r'C:\Users\me\AppData'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });
}
