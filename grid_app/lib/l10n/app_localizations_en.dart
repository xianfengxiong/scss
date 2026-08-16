// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get ok => 'OK';

  @override
  String get rename => 'Rename';

  @override
  String get save => 'Save';

  @override
  String get name => 'Name';

  @override
  String get export => 'Export';

  @override
  String get templatesTitle => 'SCSS Templates';

  @override
  String get exportAllPdf => 'Export all PDFs';

  @override
  String get exportTemplatePdf => 'Export this template\'s PDFs';

  @override
  String get sync => 'Sync';

  @override
  String get noTemplatesYet => 'No templates yet. Tap + to create one.';

  @override
  String templateSubtitle(int pages, int surveys) {
    return '$pages page(s) · $surveys survey(s)';
  }

  @override
  String get editDesign => 'Edit design';

  @override
  String confirmDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get surveysAreKept => 'Surveys filled from it are kept.';

  @override
  String get newTemplate => 'New template';

  @override
  String get renameTemplate => 'Rename template';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow system';

  @override
  String get exportTo => 'Export to:';

  @override
  String get changeDirectory => 'Change directory…';

  @override
  String get exportHint =>
      'One folder per template, one multi-page PDF per survey.\nIncremental: unchanged surveys are skipped.';

  @override
  String get preparing => 'Preparing…';

  @override
  String exportingProgress(int done, int total) {
    return 'Exporting $done/$total';
  }

  @override
  String get exporting => 'Exporting…';

  @override
  String get chooseExportDirectory => 'Choose export directory';

  @override
  String exportDirUnwritable(String error) {
    return 'Export failed: directory not writable ($error)';
  }

  @override
  String exportResult(int written, int skipped) {
    return 'Export finished: $written new · $skipped skipped (unchanged)';
  }

  @override
  String exportErrors(int count) {
    return ' · $count failed';
  }

  @override
  String surveysCount(int count) {
    return '$count survey(s)';
  }

  @override
  String get noSurveysInTemplate =>
      'No surveys yet for this template. Tap + to create one.';

  @override
  String get newSurvey => 'New survey';

  @override
  String get renameSurvey => 'Rename survey';

  @override
  String fieldsCount(int count) {
    return '$count fields';
  }

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int n) {
    return '${n}m ago';
  }

  @override
  String hoursAgo(int n) {
    return '${n}h ago';
  }

  @override
  String daysAgo(int n) {
    return '${n}d ago';
  }

  @override
  String get cols => 'Cols';

  @override
  String get rows => 'Rows';

  @override
  String builderSubtitle(int cols, int rows, int pages) {
    return '$cols × $rows grid · $pages page(s)';
  }

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String get addPageTooltip => 'Add page (inherits this page\'s grid)';

  @override
  String get deletePageTooltip => 'Delete this page';

  @override
  String deletePageTitle(int n) {
    return 'Delete page $n?';
  }

  @override
  String deletePageContent(int count) {
    return 'Its $count control(s) will be deleted with it.';
  }

  @override
  String get templateSaved => 'Template saved.';

  @override
  String get preview => 'Preview';

  @override
  String get selectControlHint =>
      'Click a control on the canvas to edit its properties';

  @override
  String get controlsDock => 'Controls';

  @override
  String get propertiesDock => 'Properties';

  @override
  String collapseDock(String title) {
    return 'Collapse $title';
  }

  @override
  String widthLabel(int n) {
    return 'Width: $n';
  }

  @override
  String get expand => 'Expand';

  @override
  String get collapse => 'Collapse';

  @override
  String get syncHostTitle => 'Sync (this computer hosts)';

  @override
  String get syncHostIntro =>
      'Connect the phone to the same Wi-Fi, open Sync on the phone, and enter this address and pairing code:';

  @override
  String get thisMachineAddress => 'This computer\'s address';

  @override
  String get noLanAddress => 'No LAN address found — check Wi-Fi/Ethernet';

  @override
  String get pairingCode => 'Pairing code';

  @override
  String serverRunning(int port) {
    return 'Server running (port $port) — keep this page open and tap Sync on the phone';
  }

  @override
  String get activityLog => 'Activity';

  @override
  String get waitingForPhone => 'Waiting for the phone…';

  @override
  String syncServerStartFailed(String error) {
    return 'Sync server failed to start: $error';
  }

  @override
  String get syncClientIntro =>
      'Open the Sync page on the computer, then enter the address and pairing code it shows. Remembered after the first success.';

  @override
  String get computerAddress => 'Computer address';

  @override
  String get addressHint => 'e.g. 192.168.1.5';

  @override
  String get startSync => 'Start sync';

  @override
  String get syncing => 'Syncing…';

  @override
  String get fillAddressAndCode =>
      'Enter the computer address and pairing code';

  @override
  String syncFailedMsg(String error) {
    return 'Sync failed: $error';
  }

  @override
  String connectingTo(String hostPort) {
    return 'Connecting to $hostPort…';
  }

  @override
  String get upToDate => 'Already up to date — nothing to sync';

  @override
  String syncDone(String parts) {
    return 'Sync finished: $parts';
  }

  @override
  String pulledTemplatesN(int n) {
    return '$n template(s) pulled';
  }

  @override
  String pushedTemplatesN(int n) {
    return '$n template(s) pushed';
  }

  @override
  String pulledSurveysN(int n) {
    return '$n survey(s) pulled';
  }

  @override
  String pushedSurveysN(int n) {
    return '$n survey(s) pushed';
  }

  @override
  String filesTransferredN(int n) {
    return '$n image(s) transferred';
  }

  @override
  String deletionsSyncedN(int n) {
    return '$n deletion(s) synced';
  }

  @override
  String get syncFetchingManifest => 'Fetching the other device\'s manifest…';

  @override
  String get syncingTemplates => 'Syncing templates…';

  @override
  String get syncingSurveys => 'Syncing surveys…';

  @override
  String pullingItem(String id) {
    return 'Pulling $id…';
  }

  @override
  String pushingItem(String id) {
    return 'Pushing $id…';
  }

  @override
  String protocolMismatch(int local, int remote) {
    return 'Protocol version mismatch (this device v$local, peer v$remote) — update both apps to the same version';
  }

  @override
  String requestTimeout(String what) {
    return '$what timed out — make sure the Sync page is open on the computer, both devices share the same Wi-Fi, and the address is correct';
  }

  @override
  String get wrongPairingCode => 'Wrong pairing code';

  @override
  String requestFailed(String what, int status) {
    return '$what failed (HTTP $status)';
  }

  @override
  String get reqConnect => 'Connect';

  @override
  String get reqManifest => 'Fetch manifest';

  @override
  String get reqTombstones => 'Sync deletions';

  @override
  String get reqDownloadImage => 'Download image';

  @override
  String get reqUploadImage => 'Upload image';

  @override
  String get reqPull => 'Pull data';

  @override
  String get reqPush => 'Push data';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get clear => 'Clear';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get openMap => 'Open map';

  @override
  String atLeastNPhotos(int min, int count) {
    return 'At least $min, now $count';
  }

  @override
  String atMostNPhotos(int max, int count) {
    return 'At most $max, now $count';
  }

  @override
  String get satelliteTitle => 'Satellite Diagram';

  @override
  String get saveSnapshot => 'Save snapshot';

  @override
  String get mapHint =>
      'Tap map to drop a pin · tap a pin to edit/delete · long-press & drag to move · Save to snapshot.';

  @override
  String get aimHint =>
      'Drag the dot to aim the device · tap elsewhere to finish.';

  @override
  String get myLocation => 'My location';

  @override
  String get locateFailed =>
      'Location failed — check location permission and GPS';

  @override
  String get pinTitle => 'Pin';

  @override
  String get pinLabelOptional => 'Label (optional)';

  @override
  String get deviceNameHint => 'Device name';

  @override
  String pageIndicator(int current, int total) {
    return '$current / $total';
  }
}
