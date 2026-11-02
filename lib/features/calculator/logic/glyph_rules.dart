// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/game_catalog.dart";

/// Whether [glyphIds] can all be inscribed together: each is one of the class's
/// [catalog], none is there twice, and they fit the slots of their type.
bool glyphsAreLegal(List<int> glyphIds, List<Glyph> catalog) {
  if (glyphIds.toSet().length != glyphIds.length) return false;
  final byId = {for (final glyph in catalog) glyph.id: glyph};
  final used = {for (final type in GlyphType.values) type: 0};
  for (final id in glyphIds) {
    final glyph = byId[id];
    if (glyph == null) return false;
    used[glyph.type] = used[glyph.type]! + 1;
  }
  return used.values.every((count) => count <= glyphSlotsPerType);
}
