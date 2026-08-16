import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @templatesTitle.
  ///
  /// In en, this message translates to:
  /// **'SCSS Templates'**
  String get templatesTitle;

  /// No description provided for @exportAllPdf.
  ///
  /// In en, this message translates to:
  /// **'Export all PDFs'**
  String get exportAllPdf;

  /// No description provided for @exportTemplatePdf.
  ///
  /// In en, this message translates to:
  /// **'Export this template\'s PDFs'**
  String get exportTemplatePdf;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @noTemplatesYet.
  ///
  /// In en, this message translates to:
  /// **'No templates yet. Tap + to create one.'**
  String get noTemplatesYet;

  /// No description provided for @templateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{pages} page(s) · {surveys} survey(s)'**
  String templateSubtitle(int pages, int surveys);

  /// No description provided for @editDesign.
  ///
  /// In en, this message translates to:
  /// **'Edit design'**
  String get editDesign;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String confirmDeleteTitle(String name);

  /// No description provided for @surveysAreKept.
  ///
  /// In en, this message translates to:
  /// **'Surveys filled from it are kept.'**
  String get surveysAreKept;

  /// No description provided for @newTemplate.
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get newTemplate;

  /// No description provided for @renameTemplate.
  ///
  /// In en, this message translates to:
  /// **'Rename template'**
  String get renameTemplate;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @exportTo.
  ///
  /// In en, this message translates to:
  /// **'Export to:'**
  String get exportTo;

  /// No description provided for @changeDirectory.
  ///
  /// In en, this message translates to:
  /// **'Change directory…'**
  String get changeDirectory;

  /// No description provided for @exportHint.
  ///
  /// In en, this message translates to:
  /// **'One folder per template, one multi-page PDF per survey.\nIncremental: unchanged surveys are skipped.'**
  String get exportHint;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get preparing;

  /// No description provided for @exportingProgress.
  ///
  /// In en, this message translates to:
  /// **'Exporting {done}/{total}'**
  String exportingProgress(int done, int total);

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get exporting;

  /// No description provided for @chooseExportDirectory.
  ///
  /// In en, this message translates to:
  /// **'Choose export directory'**
  String get chooseExportDirectory;

  /// No description provided for @exportDirUnwritable.
  ///
  /// In en, this message translates to:
  /// **'Export failed: directory not writable ({error})'**
  String exportDirUnwritable(String error);

  /// No description provided for @exportResult.
  ///
  /// In en, this message translates to:
  /// **'Export finished: {written} new · {skipped} skipped (unchanged)'**
  String exportResult(int written, int skipped);

  /// No description provided for @exportErrors.
  ///
  /// In en, this message translates to:
  /// **' · {count} failed'**
  String exportErrors(int count);

  /// No description provided for @surveysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} survey(s)'**
  String surveysCount(int count);

  /// No description provided for @noSurveysInTemplate.
  ///
  /// In en, this message translates to:
  /// **'No surveys yet for this template. Tap + to create one.'**
  String get noSurveysInTemplate;

  /// No description provided for @newSurvey.
  ///
  /// In en, this message translates to:
  /// **'New survey'**
  String get newSurvey;

  /// No description provided for @renameSurvey.
  ///
  /// In en, this message translates to:
  /// **'Rename survey'**
  String get renameSurvey;

  /// No description provided for @fieldsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} fields'**
  String fieldsCount(int count);

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String minutesAgo(int n);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String hoursAgo(int n);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String daysAgo(int n);

  /// No description provided for @cols.
  ///
  /// In en, this message translates to:
  /// **'Cols'**
  String get cols;

  /// No description provided for @rows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get rows;

  /// No description provided for @builderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{cols} × {rows} grid · {pages} page(s)'**
  String builderSubtitle(int cols, int rows, int pages);

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @addPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add page (inherits this page\'s grid)'**
  String get addPageTooltip;

  /// No description provided for @deletePageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete this page'**
  String get deletePageTooltip;

  /// No description provided for @deletePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete page {n}?'**
  String deletePageTitle(int n);

  /// No description provided for @deletePageContent.
  ///
  /// In en, this message translates to:
  /// **'Its {count} control(s) will be deleted with it.'**
  String deletePageContent(int count);

  /// No description provided for @templateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template saved.'**
  String get templateSaved;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @selectControlHint.
  ///
  /// In en, this message translates to:
  /// **'Click a control on the canvas to edit its properties'**
  String get selectControlHint;

  /// No description provided for @controlsDock.
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get controlsDock;

  /// No description provided for @propertiesDock.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get propertiesDock;

  /// No description provided for @collapseDock.
  ///
  /// In en, this message translates to:
  /// **'Collapse {title}'**
  String collapseDock(String title);

  /// No description provided for @widthLabel.
  ///
  /// In en, this message translates to:
  /// **'Width: {n}'**
  String widthLabel(int n);

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @syncHostTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync (this computer hosts)'**
  String get syncHostTitle;

  /// No description provided for @syncHostIntro.
  ///
  /// In en, this message translates to:
  /// **'Connect the phone to the same Wi-Fi, open Sync on the phone, and enter this address and pairing code:'**
  String get syncHostIntro;

  /// No description provided for @thisMachineAddress.
  ///
  /// In en, this message translates to:
  /// **'This computer\'s address'**
  String get thisMachineAddress;

  /// No description provided for @noLanAddress.
  ///
  /// In en, this message translates to:
  /// **'No LAN address found — check Wi-Fi/Ethernet'**
  String get noLanAddress;

  /// No description provided for @pairingCode.
  ///
  /// In en, this message translates to:
  /// **'Pairing code'**
  String get pairingCode;

  /// No description provided for @serverRunning.
  ///
  /// In en, this message translates to:
  /// **'Server running (port {port}) — keep this page open and tap Sync on the phone'**
  String serverRunning(int port);

  /// No description provided for @activityLog.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityLog;

  /// No description provided for @waitingForPhone.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the phone…'**
  String get waitingForPhone;

  /// No description provided for @syncServerStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync server failed to start: {error}'**
  String syncServerStartFailed(String error);

  /// No description provided for @syncClientIntro.
  ///
  /// In en, this message translates to:
  /// **'Open the Sync page on the computer, then enter the address and pairing code it shows. Remembered after the first success.'**
  String get syncClientIntro;

  /// No description provided for @computerAddress.
  ///
  /// In en, this message translates to:
  /// **'Computer address'**
  String get computerAddress;

  /// No description provided for @addressHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.5'**
  String get addressHint;

  /// No description provided for @startSync.
  ///
  /// In en, this message translates to:
  /// **'Start sync'**
  String get startSync;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @fillAddressAndCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the computer address and pairing code'**
  String get fillAddressAndCode;

  /// No description provided for @syncFailedMsg.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String syncFailedMsg(String error);

  /// No description provided for @connectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {hostPort}…'**
  String connectingTo(String hostPort);

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'Already up to date — nothing to sync'**
  String get upToDate;

  /// No description provided for @syncDone.
  ///
  /// In en, this message translates to:
  /// **'Sync finished: {parts}'**
  String syncDone(String parts);

  /// No description provided for @pulledTemplatesN.
  ///
  /// In en, this message translates to:
  /// **'{n} template(s) pulled'**
  String pulledTemplatesN(int n);

  /// No description provided for @pushedTemplatesN.
  ///
  /// In en, this message translates to:
  /// **'{n} template(s) pushed'**
  String pushedTemplatesN(int n);

  /// No description provided for @pulledSurveysN.
  ///
  /// In en, this message translates to:
  /// **'{n} survey(s) pulled'**
  String pulledSurveysN(int n);

  /// No description provided for @pushedSurveysN.
  ///
  /// In en, this message translates to:
  /// **'{n} survey(s) pushed'**
  String pushedSurveysN(int n);

  /// No description provided for @filesTransferredN.
  ///
  /// In en, this message translates to:
  /// **'{n} image(s) transferred'**
  String filesTransferredN(int n);

  /// No description provided for @deletionsSyncedN.
  ///
  /// In en, this message translates to:
  /// **'{n} deletion(s) synced'**
  String deletionsSyncedN(int n);

  /// No description provided for @syncFetchingManifest.
  ///
  /// In en, this message translates to:
  /// **'Fetching the other device\'s manifest…'**
  String get syncFetchingManifest;

  /// No description provided for @syncingTemplates.
  ///
  /// In en, this message translates to:
  /// **'Syncing templates…'**
  String get syncingTemplates;

  /// No description provided for @syncingSurveys.
  ///
  /// In en, this message translates to:
  /// **'Syncing surveys…'**
  String get syncingSurveys;

  /// No description provided for @pullingItem.
  ///
  /// In en, this message translates to:
  /// **'Pulling {id}…'**
  String pullingItem(String id);

  /// No description provided for @pushingItem.
  ///
  /// In en, this message translates to:
  /// **'Pushing {id}…'**
  String pushingItem(String id);

  /// No description provided for @protocolMismatch.
  ///
  /// In en, this message translates to:
  /// **'Protocol version mismatch (this device v{local}, peer v{remote}) — update both apps to the same version'**
  String protocolMismatch(int local, int remote);

  /// No description provided for @requestTimeout.
  ///
  /// In en, this message translates to:
  /// **'{what} timed out — make sure the Sync page is open on the computer, both devices share the same Wi-Fi, and the address is correct'**
  String requestTimeout(String what);

  /// No description provided for @wrongPairingCode.
  ///
  /// In en, this message translates to:
  /// **'Wrong pairing code'**
  String get wrongPairingCode;

  /// No description provided for @requestFailed.
  ///
  /// In en, this message translates to:
  /// **'{what} failed (HTTP {status})'**
  String requestFailed(String what, int status);

  /// No description provided for @reqConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get reqConnect;

  /// No description provided for @reqManifest.
  ///
  /// In en, this message translates to:
  /// **'Fetch manifest'**
  String get reqManifest;

  /// No description provided for @reqTombstones.
  ///
  /// In en, this message translates to:
  /// **'Sync deletions'**
  String get reqTombstones;

  /// No description provided for @reqDownloadImage.
  ///
  /// In en, this message translates to:
  /// **'Download image'**
  String get reqDownloadImage;

  /// No description provided for @reqUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload image'**
  String get reqUploadImage;

  /// No description provided for @reqPull.
  ///
  /// In en, this message translates to:
  /// **'Pull data'**
  String get reqPull;

  /// No description provided for @reqPush.
  ///
  /// In en, this message translates to:
  /// **'Push data'**
  String get reqPush;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @openMap.
  ///
  /// In en, this message translates to:
  /// **'Open map'**
  String get openMap;

  /// No description provided for @atLeastNPhotos.
  ///
  /// In en, this message translates to:
  /// **'At least {min}, now {count}'**
  String atLeastNPhotos(int min, int count);

  /// No description provided for @atMostNPhotos.
  ///
  /// In en, this message translates to:
  /// **'At most {max}, now {count}'**
  String atMostNPhotos(int max, int count);

  /// No description provided for @satelliteTitle.
  ///
  /// In en, this message translates to:
  /// **'Satellite Diagram'**
  String get satelliteTitle;

  /// No description provided for @saveSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Save snapshot'**
  String get saveSnapshot;

  /// No description provided for @mapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap map to drop a pin · tap a pin to edit/delete · long-press & drag to move · Save to snapshot.'**
  String get mapHint;

  /// No description provided for @aimHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the dot to aim the device · tap elsewhere to finish.'**
  String get aimHint;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocation;

  /// No description provided for @locateFailed.
  ///
  /// In en, this message translates to:
  /// **'Location failed — check location permission and GPS'**
  String get locateFailed;

  /// No description provided for @pinTitle.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pinTitle;

  /// No description provided for @pinLabelOptional.
  ///
  /// In en, this message translates to:
  /// **'Label (optional)'**
  String get pinLabelOptional;

  /// No description provided for @deviceNameHint.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get deviceNameHint;

  /// No description provided for @pageIndicator.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String pageIndicator(int current, int total);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
