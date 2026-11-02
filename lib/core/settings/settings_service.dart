// Flutter Imports
import "package:flutter/material.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/data_repo.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/game/game_colors.dart";
import "package:ltc/core/settings/setting_keys.dart";
import "package:ltc/core/settings/settings.dart";
import "package:ltc/core/settings/settings_repo.dart";
import "package:ltc/core/utils/extensions.dart";

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final SettingsRepo _repo = SettingsRepo();
  final DataRepo dataRepo = DataRepo();

  late Locale _locale;
  late bool _showOrderNumbers;
  late bool _tutorialSeen;
  late int _selectedExpId;
  late int _selectedClassId;

  static late Settings _settings;

  Locale get locale => _locale;
  bool get showOrderNumbers => _showOrderNumbers;
  bool get tutorialSeen => _tutorialSeen;
  int get selectedExpId => _selectedExpId;
  int get selectedClassId => _selectedClassId;
  Expansion get selectedExp => _settings.selectedExp;
  Class get selectedClass => _settings.selectedClass;

  Future<void> setSetting(String key, String value) async {
    await _repo.setSetting(key, value);
    await _update(key, value);
  }

  Future<String?> getSetting(String key) async {
    return await _repo.getSetting(key);
  }

  Future<void> initSettings() async {
    final settingsMap = await _repo.getAllSettings();

    settingsMap.putIfAbsent(
      settingsKeyLocale,
      () => defaultLanguageCode,
    );
    settingsMap.putIfAbsent(
      settingsKeyShowOrderNumbers,
      () => false.toString(),
    );

    settingsMap.putIfAbsent(settingsKeyTutorialSeen, () => false.toString());

    settingsMap.putIfAbsent(settingsKeySelectedExpId, () => 1.toString());
    settingsMap.putIfAbsent(settingsKeySelectedClassId, () => 0.toString());

    await _init(settingsMap);
  }

  Future<void> _init(Map<String, dynamic> map) async {
    if (map.containsKey(settingsKeyLocale)) {
      _locale = Locale(map[settingsKeyLocale]);
    }

    if (map.containsKey(settingsKeyShowOrderNumbers)) {
      _showOrderNumbers =
          map[settingsKeyShowOrderNumbers].toString().toLowerCase() == "true";
    } else {
      _showOrderNumbers = false;
    }

    if (map.containsKey(settingsKeyTutorialSeen)) {
      _tutorialSeen =
          map[settingsKeyTutorialSeen].toString().toLowerCase() == "true";
    } else {
      _tutorialSeen = false;
    }

    if (map.containsKey(settingsKeySelectedExpId)) {
      _selectedExpId =
          int.tryParse(map[settingsKeySelectedExpId].toString()) ?? 1;
    } else {
      _selectedExpId = 1;
    }

    if (map.containsKey(settingsKeySelectedClassId)) {
      _selectedClassId =
          int.tryParse(map[settingsKeySelectedClassId].toString()) ?? 0;
    } else {
      _selectedClassId = 0;
    }

    _settings = Settings(
      locale: _locale,
      showOrderNumbers: _showOrderNumbers,
      tutorialSeen: _tutorialSeen,
      selectedExpId: _selectedExpId,
      selectedClassId: _selectedClassId,
    );

    await updateExpAndClass();
    updateColors();
  }

  Future<void> _update(String key, String value) async {
    switch (key) {
      case settingsKeyLocale:
        _locale = Locale(value);
        break;
      case settingsKeyShowOrderNumbers:
        _showOrderNumbers = value.toLowerCase() == "true";
        break;
      case settingsKeyTutorialSeen:
        _tutorialSeen = value.toLowerCase() == "true";
        break;
      case settingsKeySelectedExpId:
        _selectedExpId = int.tryParse(value) ?? 1;
        break;
      case settingsKeySelectedClassId:
        _selectedClassId = int.tryParse(value) ?? 0;
        break;
      default:
        break;
    }

    _settings = Settings(
      locale: _locale,
      showOrderNumbers: _showOrderNumbers,
      tutorialSeen: _tutorialSeen,
      selectedExpId: _selectedExpId,
      selectedClassId: _selectedClassId,
    );

    await updateExpAndClass();
    updateColors();
  }

  Future<void> updateExpAndClass() async {
    final exps = await dataRepo.getExpansions(
      languageCode: locale.languageCode,
    );
    final exp = exps.firstWhere(
      (e) => e.id == selectedExpId,
      orElse: () => exps.first,
    );
    _settings.selectedExp = exp;

    final classes = await dataRepo.getClassesByExpansion(
      exp.id,
      languageCode: locale.languageCode,
    );
    final clazz = classes.firstWhere(
      (c) => c.id == selectedClassId,
      orElse: () => classes.first,
    );

    _settings.selectedClass = clazz;
  }

  static Settings getSettings() {
    return _settings;
  }

  void updateColors() {
    _settings.expColor = getExpansionColor(selectedExp.code);
    _settings.classColor = selectedClass.color.toColor();
  }
}
