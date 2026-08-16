import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../services/app_dirs.dart';

/// Opens the app's SQLite file lazily in the app data directory.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dir = await appDataDirectory();
    final file = File('${dir.path}/scss_grid.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
