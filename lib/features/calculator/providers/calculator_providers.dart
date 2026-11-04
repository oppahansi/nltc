// Package Imports
import "package:riverpod_annotation/riverpod_annotation.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/data_repo.dart";
import "package:ltc/core/settings/settings_service_provider.dart";

part "calculator_providers.g.dart";

/// A class's glyphs in the current language.
@Riverpod(keepAlive: true)
Future<List<Glyph>> classGlyphs(
  Ref ref, {
  required int expansionId,
  required int classId,
}) {
  final languageCode = ref.watch(settingsProvider).value?.locale.languageCode;
  return DataRepo().getGlyphs(
    expansionId: expansionId,
    classId: classId,
    languageCode: languageCode,
  );
}
