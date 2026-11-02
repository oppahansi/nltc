// Package Imports
import "package:flutter_test/flutter_test.dart";

// Project Imports
import "package:ltc/core/talent_build/share_util.dart";

void main() {
  test("share codes and Wowhead links resolve to a code", () {
    expect(classifyShareInput(" TBC-Mage-1-2-3 ").code, "tbc-mage-1-2-3");
    expect(
      classifyShareInput(
        "https://www.wowhead.com/wotlk/talent-calc/death-knight/1-2-3",
      ).code,
      "wotlk-deathknight-1-2-3",
    );
  });

  test("unusable input says why", () {
    expect(classifyShareInput("  ").error, ShareInputError.empty);
    expect(
      classifyShareInput("https://example.com/x").error,
      ShareInputError.notWowhead,
    );
    expect(
      classifyShareInput("https://www.wowhead.com/classic/talent-calc/mage")
          .error,
      ShareInputError.unsupportedWowheadLink,
    );
    expect(classifyShareInput("hello").error, ShareInputError.invalidFormat);
  });
}
