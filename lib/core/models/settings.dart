// Flutter Imports
import "package:flutter/material.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";

class Settings {
  final Locale locale;
  final bool showOrderNumbers;
  final bool tutorialSeen;
  final int selectedExpId;
  final int selectedClassId;

  late Expansion selectedExp;
  late Class selectedClass;
  late Color expColor;
  late Color classColor;

  Settings({
    required this.locale,
    this.showOrderNumbers = true,
    this.tutorialSeen = false,
    this.selectedExpId = 1,
    this.selectedClassId = 0,
  });
}
