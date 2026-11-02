// Package Imports
import "package:flutter_test/flutter_test.dart";

// Project Imports
import "package:ltc/core/game/game_catalog.dart";

void main() {
  test("editions of an expansion share an era and its point cap", () {
    for (final (original, classic, points) in [
      ("vanilla", "classic_vanilla", 51),
      ("tbc", "classic_tbc", 61),
      ("wotlk", "classic_wotlk", 71),
    ]) {
      expect(eraOf(classic), original);
      expect(maxTalentPoints(original), points);
      expect(maxTalentPoints(classic), points);
    }
    expect(maxTalentPoints("unknown"), 0);
  });

  test("labels name the edition and the era", () {
    expect(expansionLabel("tbc"), "Original TBC");
    expect(expansionLabel("classic_wotlk"), "Classic WotLK");
  });
}
