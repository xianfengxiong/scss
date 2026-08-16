import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Root directory for app data (the SQLite database + survey_images).
///
/// On Windows `getApplicationDocumentsDirectory()` is the user's real
/// `Documents\` folder — dropping a sqlite file and a UUID image dump there
/// would pollute it, so Windows uses the per-app support dir
/// (`%APPDATA%\com.example\scss_grid`). macOS (sandbox-container Documents)
/// and Android (app-private Documents) keep their original location — moving
/// them would strand data already written by installed builds.
Future<Directory> appDataDirectory() => Platform.isWindows
    ? getApplicationSupportDirectory()
    : getApplicationDocumentsDirectory();
