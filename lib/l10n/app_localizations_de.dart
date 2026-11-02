// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get add => 'hinzufügen';

  @override
  String get cancel => 'abbrechen';

  @override
  String get delete => 'löschen';

  @override
  String get disabled => 'deaktiviert';

  @override
  String get wow_class => 'klasse';

  @override
  String get enabled => 'aktiviert';

  @override
  String get english => 'englisch';

  @override
  String get error => 'fehler';

  @override
  String get expansion => 'erweiterung';

  @override
  String get german => 'deutsch';

  @override
  String get import => 'importieren';

  @override
  String get language => 'sprache';

  @override
  String get loading => 'lädt';

  @override
  String get rank => 'rang';

  @override
  String get region => 'region';

  @override
  String get remove => 'entfernen';

  @override
  String get required => 'erforderlich';

  @override
  String get reset => 'zurücksetzen';

  @override
  String get restore => 'wiederherstellen';

  @override
  String get retry => 'wiederholen';

  @override
  String get save => 'speichern';

  @override
  String get server => 'server';

  @override
  String get settings => 'einstellungen';

  @override
  String get spent => 'ausgegeben';

  @override
  String get tree => 'baum';

  @override
  String get all_ranks => 'Alle Ränge';

  @override
  String get build_deleted => 'Build gelöscht.';

  @override
  String get build_imported => 'Build importiert.';

  @override
  String get build_order => 'Build-Reihenfolge';

  @override
  String build_saved(Object value) {
    return 'Build gespeichert. $value';
  }

  @override
  String get build_title => 'Build-Titel';

  @override
  String get character_builds => 'Charakter-Builds';

  @override
  String get character_name => 'Charaktername';

  @override
  String get delete_build => 'Build löschen';

  @override
  String get e_g => 'z.B.';

  @override
  String get invalid_format => 'Ungültiges Format';

  @override
  String get invalid_title => 'Ungültiger Titel';

  @override
  String get load_build => 'Build laden';

  @override
  String get load_builds => 'Builds laden';

  @override
  String get load_more => 'Mehr laden';

  @override
  String get next_rank => 'Nächster Rang';

  @override
  String get recent_builds => 'Letzte Builds';

  @override
  String get plan_build => 'Build planen';

  @override
  String get save_build => 'Build speichern';

  @override
  String get export_db => 'Datenbank exportieren';

  @override
  String get export_canceled => 'Export abgebrochen';

  @override
  String get export_failed => 'Export fehlgeschlagen';

  @override
  String get export_import => 'Export/Import';

  @override
  String get export_import_hint =>
      'Werksreset des Telefons löscht lokale Backups. Verschieben Sie das Backup nach dem Export von Ihrem Telefon (Computer/Cloud), damit Sie es später wiederherstellen können.';

  @override
  String get export_success => 'Export erfolgreich';

  @override
  String get failed_to_import_build =>
      'Build konnte nicht importiert werden. Bitte überprüfe, ob der Code korrekt ist.';

  @override
  String get failed_to_load_builds =>
      'Build-Liste konnte nicht geladen werden. Bitte überprüfe deine Internetverbindung.';

  @override
  String get failed_to_load_realms =>
      'Realm-Liste konnte nicht geladen werden. Bitte überprüfe deine Internetverbindung.';

  @override
  String get import_build_code => 'Import Build-Url/-Code';

  @override
  String get import_canceled => 'Import abgebrochen';

  @override
  String get import_db => 'Datenbank importieren';

  @override
  String get import_empty => 'Darf nicht leer sein.';

  @override
  String get import_failed => 'Import fehlgeschlagen';

  @override
  String get import_vlaidation_only_wowhead =>
      'Es werden nur Wowhead TBC- oder WotLK-Talentrechner-URLs unterstützt.';

  @override
  String get import_from_share_code => 'Importiere aus Url / Code';

  @override
  String get no_builds_found => 'Keine Builds gefunden.';

  @override
  String get no_points_spent => 'Keine Punkte ausgegeben.';

  @override
  String get no_saved_builds => 'Keine gespeicherten Builds.';

  @override
  String get not_found => 'Nicht gefunden.';

  @override
  String get nothing_to_save => 'Nichts zu speichern.';

  @override
  String get please_select_a_realm => 'Bitte wähle einen Realm.';

  @override
  String get pick_a_backup_file => 'Backup-Datei auswählen';

  @override
  String get prompt_for_exit => 'Wird beim nächsten Versuch beendet.';

  @override
  String removed_point_in(Object value) {
    return 'Punkt in $value entfernt.';
  }

  @override
  String get restore_db => 'Datenbank wiederherstellen';

  @override
  String get restore_done_restart =>
      'Wiederhergestellt. Bitte starten Sie die App neu.';

  @override
  String get restore_warning =>
      'Dies wird Ihre aktuellen Daten überschreiben. Fortfahren?';

  @override
  String get save_backup_to => 'Backup in Dateien/Downloads sichern';

  @override
  String get save_to_phone => 'Auf Telefon speichern?';

  @override
  String get share_build_url => 'Build-URL teilen';

  @override
  String get share_build_code => 'Build-Code teilen';

  @override
  String get show_build_order => 'Build-Reihenfolge anzeigen';

  @override
  String get unavailable_for_this_expansion =>
      'Für diese Erweiterung nicht verfügbar.';

  @override
  String get vanilla_only => 'Nur für Anniversary Realms';

  @override
  String get tutorialTitle => 'Talentrechner Tutorial';

  @override
  String get tutorialAddPoints => 'Punkte hinzufügen';

  @override
  String get tutorialAddPointsBody =>
      'Tippe auf ein Talent (aktiv = farbiger Rand), um einen Rang zu vergeben.';

  @override
  String get tutorialDetailsRanks => 'Details & Ränge';

  @override
  String get tutorialDetailsRanksBody =>
      'Lange auf ein Talent drücken, um Beschreibungen zu sehen, Ränge hinzuzufügen/zu entfernen oder zukünftige Ränge anzuzeigen.';

  @override
  String get tutorialUndo => 'Rückgängig';

  @override
  String get tutorialUndoBody =>
      'Verwende die schwebende Rückgängig-Taste, um den letzten Punkt zurückzunehmen (beachtet Abhängigkeiten).';

  @override
  String get tutorialOrderNumbers => 'Reihenfolge-Nummern';

  @override
  String get tutorialOrderNumbersBody =>
      'Aktiviere Reihenfolge-Nummern in den Einstellungen, um die Sequenz anzuzeigen.';

  @override
  String get tutorialShareImport => 'Teilen / Import';

  @override
  String get tutorialShareImportBody =>
      'Verwende Teil-Codes oder Wowhead-Links (automatisch normalisiert), um Builds zu laden oder zu exportieren.';

  @override
  String get tutorialSaveBuilds => 'Builds speichern';

  @override
  String get tutorialSaveBuildsBody =>
      'Speichere mit einem eigenen Titel; Titel aktualisieren sich automatisch beim Sprachwechsel.';

  @override
  String get tutorialDependencies => 'Abhängigkeiten';

  @override
  String get tutorialDependenciesBody =>
      'Pfeile zeigen Voraussetzungen; maximiere das Quell-Talent, um das abhängige freizuschalten.';

  @override
  String get tutorialRowGating => 'Reihenbegrenzung';

  @override
  String get tutorialRowGatingBody =>
      'Pro Reihenstufe werden 5 Punkte benötigt, bevor du tiefer investieren kannst (Reihe * 5-Regel).';

  @override
  String get tutorialGotIt => 'Verstanden';
}
