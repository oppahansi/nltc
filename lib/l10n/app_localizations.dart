import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

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
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'add'**
  String get add;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'delete'**
  String get delete;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'disabled'**
  String get disabled;

  /// No description provided for @wow_class.
  ///
  /// In en, this message translates to:
  /// **'class'**
  String get wow_class;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'enabled'**
  String get enabled;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'english'**
  String get english;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'error'**
  String get error;

  /// No description provided for @expansion.
  ///
  /// In en, this message translates to:
  /// **'expansion'**
  String get expansion;

  /// No description provided for @german.
  ///
  /// In en, this message translates to:
  /// **'german'**
  String get german;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'import'**
  String get import;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'language'**
  String get language;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'loading'**
  String get loading;

  /// No description provided for @rank.
  ///
  /// In en, this message translates to:
  /// **'rank'**
  String get rank;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'remove'**
  String get remove;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'reset'**
  String get reset;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'restore'**
  String get restore;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'save'**
  String get save;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'settings'**
  String get settings;

  /// No description provided for @spent.
  ///
  /// In en, this message translates to:
  /// **'spent'**
  String get spent;

  /// No description provided for @tree.
  ///
  /// In en, this message translates to:
  /// **'tree'**
  String get tree;

  /// No description provided for @all_ranks.
  ///
  /// In en, this message translates to:
  /// **'All Ranks'**
  String get all_ranks;

  /// No description provided for @build_deleted.
  ///
  /// In en, this message translates to:
  /// **'Build deleted.'**
  String get build_deleted;

  /// No description provided for @build_imported.
  ///
  /// In en, this message translates to:
  /// **'Build imported.'**
  String get build_imported;

  /// No description provided for @build_order.
  ///
  /// In en, this message translates to:
  /// **'Build Order'**
  String get build_order;

  /// No description provided for @build_saved.
  ///
  /// In en, this message translates to:
  /// **'Build saved. {value}'**
  String build_saved(Object value);

  /// No description provided for @build_title.
  ///
  /// In en, this message translates to:
  /// **'Build Title'**
  String get build_title;

  /// No description provided for @delete_build.
  ///
  /// In en, this message translates to:
  /// **'Delete Build'**
  String get delete_build;

  /// No description provided for @e_g.
  ///
  /// In en, this message translates to:
  /// **'e.g.'**
  String get e_g;

  /// No description provided for @invalid_format.
  ///
  /// In en, this message translates to:
  /// **'Invalid format'**
  String get invalid_format;

  /// No description provided for @invalid_title.
  ///
  /// In en, this message translates to:
  /// **'Invalid title'**
  String get invalid_title;

  /// No description provided for @load_build.
  ///
  /// In en, this message translates to:
  /// **'Load Build'**
  String get load_build;

  /// No description provided for @load_more.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get load_more;

  /// No description provided for @next_rank.
  ///
  /// In en, this message translates to:
  /// **'Next Rank'**
  String get next_rank;

  /// No description provided for @recent_builds.
  ///
  /// In en, this message translates to:
  /// **'Recent Builds'**
  String get recent_builds;

  /// No description provided for @plan_build.
  ///
  /// In en, this message translates to:
  /// **'Plan Build'**
  String get plan_build;

  /// No description provided for @save_build.
  ///
  /// In en, this message translates to:
  /// **'Save Build'**
  String get save_build;

  /// No description provided for @export_db.
  ///
  /// In en, this message translates to:
  /// **'Export database'**
  String get export_db;

  /// No description provided for @export_canceled.
  ///
  /// In en, this message translates to:
  /// **'Export canceled'**
  String get export_canceled;

  /// No description provided for @export_failed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get export_failed;

  /// No description provided for @export_import.
  ///
  /// In en, this message translates to:
  /// **'Export/Import'**
  String get export_import;

  /// No description provided for @export_import_hint.
  ///
  /// In en, this message translates to:
  /// **'Phone factory resets erase local backups. After exporting, move the backup off the phone (computer/cloud) so you can restore it later.'**
  String get export_import_hint;

  /// No description provided for @export_success.
  ///
  /// In en, this message translates to:
  /// **'Export successful'**
  String get export_success;

  /// No description provided for @failed_to_import_build.
  ///
  /// In en, this message translates to:
  /// **'Failed to import build. Make sure the code is correct.'**
  String get failed_to_import_build;

  /// No description provided for @failed_to_load_builds.
  ///
  /// In en, this message translates to:
  /// **'Failed to load builds. Make sure you have internet access.'**
  String get failed_to_load_builds;

  /// No description provided for @import_build_code.
  ///
  /// In en, this message translates to:
  /// **'Import Build Url / Code'**
  String get import_build_code;

  /// No description provided for @import_canceled.
  ///
  /// In en, this message translates to:
  /// **'Import canceled'**
  String get import_canceled;

  /// No description provided for @import_db.
  ///
  /// In en, this message translates to:
  /// **'Import database'**
  String get import_db;

  /// No description provided for @import_empty.
  ///
  /// In en, this message translates to:
  /// **'Cannot be empty.'**
  String get import_empty;

  /// No description provided for @import_failed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get import_failed;

  /// No description provided for @import_vlaidation_only_wowhead.
  ///
  /// In en, this message translates to:
  /// **'Only Wowhead TBC or WotLK talent calculator URLs are supported.'**
  String get import_vlaidation_only_wowhead;

  /// No description provided for @import_from_share_code.
  ///
  /// In en, this message translates to:
  /// **'Import from Url / Code'**
  String get import_from_share_code;

  /// No description provided for @no_builds_found.
  ///
  /// In en, this message translates to:
  /// **'No builds found.'**
  String get no_builds_found;

  /// No description provided for @no_points_spent.
  ///
  /// In en, this message translates to:
  /// **'No points spent.'**
  String get no_points_spent;

  /// No description provided for @no_saved_builds.
  ///
  /// In en, this message translates to:
  /// **'No saved builds.'**
  String get no_saved_builds;

  /// No description provided for @not_found.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get not_found;

  /// No description provided for @nothing_to_save.
  ///
  /// In en, this message translates to:
  /// **'Nothing to save.'**
  String get nothing_to_save;

  /// No description provided for @pick_a_backup_file.
  ///
  /// In en, this message translates to:
  /// **'Pick a backup file'**
  String get pick_a_backup_file;

  /// No description provided for @prompt_for_exit.
  ///
  /// In en, this message translates to:
  /// **'Will exit on next attempt.'**
  String get prompt_for_exit;

  /// No description provided for @removed_point_in.
  ///
  /// In en, this message translates to:
  /// **'Removed point in {value}.'**
  String removed_point_in(Object value);

  /// No description provided for @restore_db.
  ///
  /// In en, this message translates to:
  /// **'Restore database'**
  String get restore_db;

  /// No description provided for @restore_done_restart.
  ///
  /// In en, this message translates to:
  /// **'Restored. Please restart the app.'**
  String get restore_done_restart;

  /// No description provided for @restore_warning.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite your current data. Continue?'**
  String get restore_warning;

  /// No description provided for @save_backup_to.
  ///
  /// In en, this message translates to:
  /// **'Save backup to file/downloads'**
  String get save_backup_to;

  /// No description provided for @save_to_phone.
  ///
  /// In en, this message translates to:
  /// **'Save to phone?'**
  String get save_to_phone;

  /// No description provided for @share_build_url.
  ///
  /// In en, this message translates to:
  /// **'Share Build URL'**
  String get share_build_url;

  /// No description provided for @share_build_code.
  ///
  /// In en, this message translates to:
  /// **'Share Build Code'**
  String get share_build_code;

  /// No description provided for @show_build_order.
  ///
  /// In en, this message translates to:
  /// **'Show Build Order'**
  String get show_build_order;

  /// No description provided for @unavailable_for_this_expansion.
  ///
  /// In en, this message translates to:
  /// **'Unavailable for this expansion.'**
  String get unavailable_for_this_expansion;

  /// No description provided for @tutorialTitle.
  ///
  /// In en, this message translates to:
  /// **'Talent Calculator Tutorial'**
  String get tutorialTitle;

  /// No description provided for @tutorialAddPoints.
  ///
  /// In en, this message translates to:
  /// **'Add Points'**
  String get tutorialAddPoints;

  /// No description provided for @tutorialAddPointsBody.
  ///
  /// In en, this message translates to:
  /// **'Tap a talent (enabled = colored border) to invest a rank.'**
  String get tutorialAddPointsBody;

  /// No description provided for @tutorialDetailsRanks.
  ///
  /// In en, this message translates to:
  /// **'Details & Ranks'**
  String get tutorialDetailsRanks;

  /// No description provided for @tutorialDetailsRanksBody.
  ///
  /// In en, this message translates to:
  /// **'Long-press a talent to view descriptions, add/remove, or see future ranks.'**
  String get tutorialDetailsRanksBody;

  /// No description provided for @tutorialUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get tutorialUndo;

  /// No description provided for @tutorialUndoBody.
  ///
  /// In en, this message translates to:
  /// **'Use the floating Undo button to revert the last point (respects dependencies).'**
  String get tutorialUndoBody;

  /// No description provided for @tutorialOrderNumbers.
  ///
  /// In en, this message translates to:
  /// **'Order Numbers'**
  String get tutorialOrderNumbers;

  /// No description provided for @tutorialOrderNumbersBody.
  ///
  /// In en, this message translates to:
  /// **'Enable order numbers in settings to see the sequence overlay.'**
  String get tutorialOrderNumbersBody;

  /// No description provided for @tutorialShareImport.
  ///
  /// In en, this message translates to:
  /// **'Share / Import'**
  String get tutorialShareImport;

  /// No description provided for @tutorialShareImportBody.
  ///
  /// In en, this message translates to:
  /// **'Use share codes or Wowhead links (auto normalized) to load or export builds.'**
  String get tutorialShareImportBody;

  /// No description provided for @tutorialSaveBuilds.
  ///
  /// In en, this message translates to:
  /// **'Save Builds'**
  String get tutorialSaveBuilds;

  /// No description provided for @tutorialSaveBuildsBody.
  ///
  /// In en, this message translates to:
  /// **'Save with a custom title; titles auto-update when you switch language.'**
  String get tutorialSaveBuildsBody;

  /// No description provided for @tutorialDependencies.
  ///
  /// In en, this message translates to:
  /// **'Dependencies'**
  String get tutorialDependencies;

  /// No description provided for @tutorialDependenciesBody.
  ///
  /// In en, this message translates to:
  /// **'Arrows show prerequisites; max the source talent to unlock its dependent.'**
  String get tutorialDependenciesBody;

  /// No description provided for @tutorialRowGating.
  ///
  /// In en, this message translates to:
  /// **'Row Gating'**
  String get tutorialRowGating;

  /// No description provided for @tutorialRowGatingBody.
  ///
  /// In en, this message translates to:
  /// **'Need 5 points per row tier before investing deeper (row * 5 rule).'**
  String get tutorialRowGatingBody;

  /// No description provided for @tutorialGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get tutorialGotIt;

  /// No description provided for @edition_original.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get edition_original;

  /// No description provided for @edition_classic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get edition_classic;

  /// No description provided for @edition_forever.
  ///
  /// In en, this message translates to:
  /// **'Forever'**
  String get edition_forever;
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
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
