// Package Imports
import "package:flutter_test/flutter_test.dart";

// Project Imports
import "package:ltc/core/talent_build/share_util.dart";

void main() {
  test("share codes resolve to a normalized code", () {
    expect(classifyShareInput(" TBC-Mage-1-2-3 ").code, "tbc-mage-1-2-3");
  });

  test("unusable input says why", () {
    expect(classifyShareInput("  ").error, ShareInputError.empty);
    expect(classifyShareInput("hello").error, ShareInputError.invalidFormat);
    expect(
      classifyShareInput(
        "https://www.wowhead.com/wotlk/talent-calc/death-knight/1-2-3",
      ).error,
      ShareInputError.invalidFormat,
    );
  });
}
