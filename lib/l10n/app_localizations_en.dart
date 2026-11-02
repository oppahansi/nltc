// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get add => 'add';

  @override
  String get cancel => 'cancel';

  @override
  String get delete => 'delete';

  @override
  String get disabled => 'disabled';

  @override
  String get wow_class => 'class';

  @override
  String get enabled => 'enabled';

  @override
  String get english => 'english';

  @override
  String get error => 'error';

  @override
  String get expansion => 'expansion';

  @override
  String get german => 'german';

  @override
  String get import => 'import';

  @override
  String get language => 'language';

  @override
  String get loading => 'loading';

  @override
  String get rank => 'rank';

  @override
  String get remove => 'remove';

  @override
  String get reset => 'reset';

  @override
  String get restore => 'restore';

  @override
  String get save => 'save';

  @override
  String get settings => 'settings';

  @override
  String get spent => 'spent';

  @override
  String get tree => 'tree';

  @override
  String get all_ranks => 'All Ranks';

  @override
  String get build_deleted => 'Build deleted.';

  @override
  String get build_imported => 'Build imported.';

  @override
  String get build_order => 'Build Order';

  @override
  String build_saved(Object value) {
    return 'Build saved. $value';
  }

  @override
  String get build_title => 'Build Title';

  @override
  String get delete_build => 'Delete Build';

  @override
  String get e_g => 'e.g.';

  @override
  String get invalid_format => 'Invalid format';

  @override
  String get invalid_title => 'Invalid title';

  @override
  String get load_build => 'Load Build';

  @override
  String get load_more => 'Load more';

  @override
  String get next_rank => 'Next Rank';

  @override
  String get recent_builds => 'Recent Builds';

  @override
  String get plan_build => 'Plan Build';

  @override
  String get save_build => 'Save Build';

  @override
  String get export_db => 'Export database';

  @override
  String get export_canceled => 'Export canceled';

  @override
  String get export_failed => 'Export failed';

  @override
  String get export_import => 'Export/Import';

  @override
  String get export_import_hint =>
      'Phone factory resets erase local backups. After exporting, move the backup off the phone (computer/cloud) so you can restore it later.';

  @override
  String get export_success => 'Export successful';

  @override
  String get failed_to_import_build =>
      'Failed to import build. Make sure the code is correct.';

  @override
  String get failed_to_load_builds =>
      'Failed to load builds. Make sure you have internet access.';

  @override
  String get import_build_code => 'Import Build Url / Code';

  @override
  String get import_canceled => 'Import canceled';

  @override
  String get import_db => 'Import database';

  @override
  String get import_empty => 'Cannot be empty.';

  @override
  String get import_failed => 'Import failed';

  @override
  String get import_vlaidation_only_wowhead =>
      'Only Wowhead TBC or WotLK talent calculator URLs are supported.';

  @override
  String get import_from_share_code => 'Import from Url / Code';

  @override
  String get no_builds_found => 'No builds found.';

  @override
  String get no_points_spent => 'No points spent.';

  @override
  String get no_saved_builds => 'No saved builds.';

  @override
  String get not_found => 'Not found.';

  @override
  String get nothing_to_save => 'Nothing to save.';

  @override
  String get pick_a_backup_file => 'Pick a backup file';

  @override
  String get prompt_for_exit => 'Will exit on next attempt.';

  @override
  String removed_point_in(Object value) {
    return 'Removed point in $value.';
  }

  @override
  String get restore_db => 'Restore database';

  @override
  String get restore_done_restart => 'Restored. Please restart the app.';

  @override
  String get restore_warning =>
      'This will overwrite your current data. Continue?';

  @override
  String get save_backup_to => 'Save backup to file/downloads';

  @override
  String get save_to_phone => 'Save to phone?';

  @override
  String get share_build_url => 'Share Build URL';

  @override
  String get share_build_code => 'Share Build Code';

  @override
  String get show_build_order => 'Show Build Order';

  @override
  String get unavailable_for_this_expansion =>
      'Unavailable for this expansion.';

  @override
  String get tutorialTitle => 'Talent Calculator Tutorial';

  @override
  String get tutorialAddPoints => 'Add Points';

  @override
  String get tutorialAddPointsBody =>
      'Tap a talent (enabled = colored border) to invest a rank.';

  @override
  String get tutorialDetailsRanks => 'Details & Ranks';

  @override
  String get tutorialDetailsRanksBody =>
      'Long-press a talent to view descriptions, add/remove, or see future ranks.';

  @override
  String get tutorialUndo => 'Undo';

  @override
  String get tutorialUndoBody =>
      'Use the floating Undo button to revert the last point (respects dependencies).';

  @override
  String get tutorialOrderNumbers => 'Order Numbers';

  @override
  String get tutorialOrderNumbersBody =>
      'Enable order numbers in settings to see the sequence overlay.';

  @override
  String get tutorialShareImport => 'Share / Import';

  @override
  String get tutorialShareImportBody =>
      'Use share codes or Wowhead links (auto normalized) to load or export builds.';

  @override
  String get tutorialSaveBuilds => 'Save Builds';

  @override
  String get tutorialSaveBuildsBody =>
      'Save with a custom title; titles auto-update when you switch language.';

  @override
  String get tutorialDependencies => 'Dependencies';

  @override
  String get tutorialDependenciesBody =>
      'Arrows show prerequisites; max the source talent to unlock its dependent.';

  @override
  String get tutorialRowGating => 'Row Gating';

  @override
  String get tutorialRowGatingBody =>
      'Need 5 points per row tier before investing deeper (row * 5 rule).';

  @override
  String get tutorialGotIt => 'Got it';

  @override
  String get edition_original => 'Original';

  @override
  String get edition_classic => 'Classic';

  @override
  String get edition_forever => 'Forever';

  @override
  String legacyPointsSpent(int spent, int cap) {
    return 'Legacy: $spent/$cap';
  }

  @override
  String get buildOrderTalents => 'Talents';

  @override
  String get buildOrderLegacy => 'Legacy';
}
