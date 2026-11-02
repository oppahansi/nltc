// Dart Imports
import "dart:io";

// Flutter Imports
import "package:flutter_test/flutter_test.dart";

/// Features may only depend on each other in these directions, which keeps the
/// graph free of cycles. Only `app/` may import every screen.
const allowedFeatureEdges = {
  "home": {"builds", "calculator"},
  "builds": {"calculator"},
  "calculator": <String>{},
  "settings": <String>{},
};

/// Violations being worked off. This list may only ever shrink.
const knownViolations = <String>{};

final _import = RegExp(
  r"""^import\s+["']package:ltc/([^"']+)["']""",
  multiLine: true,
);

/// Every project import in `lib/`, as "from -> to", relative to `lib/`.
List<(String, String)> projectImports() {
  return [
    for (final file in Directory(
      "lib",
    ).listSync(recursive: true).whereType<File>())
      if (file.path.endsWith(".dart") && !file.path.endsWith(".g.dart"))
        for (final match in _import.allMatches(file.readAsStringSync()))
          (file.path.substring("lib/".length), match.group(1)!),
  ];
}

String? violation(String from, String to) {
  if (from.startsWith("core/") &&
      (to.startsWith("features/") || to.startsWith("app/"))) {
    return "core must not depend on features or app";
  }
  if (from.startsWith("features/")) {
    if (to.startsWith("app/")) return "features must not depend on app";
    if (to.startsWith("features/")) {
      final fromFeature = from.split("/")[1];
      final toFeature = to.split("/")[1];
      if (fromFeature != toFeature &&
          !(allowedFeatureEdges[fromFeature] ?? const {}).contains(toFeature)) {
        return "$fromFeature must not depend on $toFeature";
      }
    }
  }
  return null;
}

void main() {
  test("imports follow the dependency rules", () {
    final found = <String, String>{};
    for (final (from, to) in projectImports()) {
      final reason = violation(from, to);
      if (reason != null) found["$from -> $to"] = reason;
    }

    final unexpected = {
      for (final e in found.entries)
        if (!knownViolations.contains(e.key)) "${e.key} (${e.value})",
    };
    expect(unexpected, isEmpty);

    final fixed = knownViolations.difference(found.keys.toSet());
    expect(
      fixed,
      isEmpty,
      reason: "These no longer occur: remove them from knownViolations.",
    );
  });

  test("the rules catch what they are meant to catch", () {
    expect(violation("core/a.dart", "features/home/b.dart"), isNotNull);
    expect(
      violation("features/calculator/a.dart", "features/home/b.dart"),
      isNotNull,
    );
    expect(violation("features/home/a.dart", "app/routes.dart"), isNotNull);
    expect(violation("features/home/a.dart", "features/builds/b.dart"), isNull);
    expect(violation("features/home/a.dart", "features/home/b.dart"), isNull);
    expect(violation("app/app.dart", "features/settings/a.dart"), isNull);
  });

  test("every feature is covered by the rules", () {
    final features = Directory("lib/features")
        .listSync()
        .whereType<Directory>()
        .map((d) => d.path.split("/").last)
        .toSet();
    expect(features, allowedFeatureEdges.keys.toSet());
  });
}
