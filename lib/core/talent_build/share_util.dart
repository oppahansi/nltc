// Dart Imports
import "dart:core";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/talent_build/class_build.dart";

String buildShareUrl(ClassBuild build) {
  final expansion = build.expansionCode.toLowerCase(); // already canonical

  // Use stable internal class code (not localized name)
  final rawClassCode =
      idsToClasses[build.classId]?.toLowerCase() ??
      build.className.toLowerCase();
  final classSlug = _slugifyClass(rawClassCode, forWowhead: true);

  final treeStrings = <String>[];
  for (var i = 0; i < build.talentTreeTalents.length; i++) {
    treeStrings.add(_encodeTree(build.talentTreeTalents[i]));
  }

  if (expansion == "tbc") {
    return "https://www.wowhead.com/tbc/talent-calc/$classSlug/${treeStrings.join("-")}";
  }
  if (expansion == "wotlk") {
    return "https://www.wowhead.com/wotlk/talent-calc/$classSlug/${treeStrings.join("-")}";
  }

  return "Unsupported expansion for url sharing";
}

// New: compact import/export code: exp-class-tree1-tree2-tree3
String buildShareCode(ClassBuild build) {
  final exp = build.expansionCode.toLowerCase();

  // Stable internal class code
  final rawClassCode =
      idsToClasses[build.classId]?.toLowerCase() ??
      build.className.toLowerCase();
  final classCode = _slugifyClass(rawClassCode, forWowhead: false);

  final treeStrings = <String>[];
  for (var i = 0; i < build.talentTreeTalents.length; i++) {
    treeStrings.add(_encodeTree(build.talentTreeTalents[i]));
  }
  return "$exp-$classCode-${treeStrings.join("-")}";
}

class ParsedShareCode {
  final String expansion;
  final String classCode;
  final List<String> trees; // length 3
  ParsedShareCode(this.expansion, this.classCode, this.trees);
}

final _codeRegex = RegExp(
  r"^(vanilla|tbc|wotlk)-([a-z]+)-([0-9]+)-([0-9]+)-([0-9]+)$",
);

ParsedShareCode? parseShareCode(String code) {
  final m = _codeRegex.firstMatch(code.trim().toLowerCase());
  if (m == null) return null;
  final expansion = m.group(1)!;
  final cls = m.group(2)!;
  final t1 = m.group(3)!;
  final t2 = m.group(4)!;
  final t3 = m.group(5)!;
  return ParsedShareCode(expansion, cls, [t1, t2, t3]);
}

// Optional helper to check share availability.
bool canShareBuild(ClassBuild build) =>
    build.expansionCode.toLowerCase() != "vanilla";

String? shareCodeFromWowheadUrl(String input) {
  final trimmed = input.trim();
  if (!trimmed.contains("wowhead.com")) return null;

  Uri uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    return null;
  }

  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty) return null;

  // Detect expansion
  String? expansion;
  if (segs.contains("tbc")) {
    expansion = "tbc";
  } else if (segs.contains("wotlk")) {
    expansion = "wotlk";
  } else {
    return null;
  }

  final idxCalc = segs.indexOf("talent-calc");
  if (idxCalc == -1 || idxCalc + 2 >= segs.length) return null;

  final classSlug = segs[idxCalc + 1];
  // Remaining segment(s) after class may contain tree codes (usually one segment)
  final treeSegment = segs.sublist(idxCalc + 2).join("-");
  if (treeSegment.isEmpty) return null;

  final parts = treeSegment.split("-");
  if (parts.length < 3) return null;

  // First three digit groups are trees
  final tree1 = parts[0];
  final tree2 = parts[1];
  final tree3 = parts[2];

  bool allDigits(String s) => RegExp(r"^[0-9]+$").hasMatch(s);
  if (!allDigits(tree1) || !allDigits(tree2) || !allDigits(tree3)) {
    return null;
  }

  // Map wowhead class slug to internal class code
  String classCode;
  switch (classSlug) {
    case "death-knight":
      classCode = "deathknight";
      break;
    default:
      classCode = classSlug;
  }

  return "$expansion-$classCode-$tree1-$tree2-$tree3";
}

// Normalize any user input (share code or wowhead url) to a share code.
String? normalizeShareInputToCode(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return null;

  // Already a share code?
  if (parseShareCode(raw) != null) {
    return raw.toLowerCase();
  }

  // Try wowhead URL
  final fromUrl = shareCodeFromWowheadUrl(raw);
  if (fromUrl != null && parseShareCode(fromUrl) != null) {
    return fromUrl;
  }

  return null;
}

String _encodeTree(List<Talent> talents) {
  final sorted = [...talents]
    ..sort((a, b) {
      final r = a.row.compareTo(b.row);
      if (r != 0) return r;
      final c = a.column.compareTo(b.column);
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    });
  final sb = StringBuffer();
  for (final t in sorted) {
    sb.write(t.currentRank.clamp(0, 9));
  }
  return sb.toString();
}

String _slugifyClass(String classCode, {required bool forWowhead}) {
  final key = classCode
      .toLowerCase()
      .replaceAll(" ", "")
      .replaceAll("’", "")
      .replaceAll("'", "");
  switch (key) {
    case "deathknight":
      return forWowhead ? "death-knight" : "deathknight";
    default:
      return key;
  }
}
