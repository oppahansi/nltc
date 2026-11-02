// Dart Imports
import "dart:core";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/talent_build/class_build.dart";

// Compact import/export code: exp-class-tree1-tree2-tree3
String buildShareCode(ClassBuild build) {
  final exp = build.expansionCode.toLowerCase();

  // Stable internal class code
  final rawClassCode =
      idsToClasses[build.classId]?.toLowerCase() ??
      build.className.toLowerCase();
  final classCode = _slugifyClass(rawClassCode);

  final treeStrings = <String>[];
  for (var i = 0; i < build.talentTreeTalents.length; i++) {
    treeStrings.add(_encodeTree(build.talentTreeTalents[i]));
  }
  return "$exp-$classCode-${treeStrings.join("-")}";
}

class ParsedShareCode {
  final String expansion;
  final String classCode;
  final List<String> trees; // 3, or 6 with Forever's Legacy trees
  ParsedShareCode(this.expansion, this.classCode, this.trees);
}

final _codeRegex = RegExp(
  r"^([a-z_]+)-([a-z]+)-([0-9]+)-([0-9]+)-([0-9]+)(?:-([0-9]+)-([0-9]+)-([0-9]+))?$",
);

ParsedShareCode? parseShareCode(String code) {
  final m = _codeRegex.firstMatch(code.trim().toLowerCase());
  if (m == null) return null;
  final expansion = m.group(1)!;
  if (!expansionsToIds.containsKey(expansion)) return null;
  final cls = m.group(2)!;
  final trees = [for (var i = 3; i <= 8; i++) ?m.group(i)];
  return ParsedShareCode(expansion, cls, trees);
}

enum ShareInputError { empty, invalidFormat }

/// What pasted share input resolved to: a share code, or why it can't be used.
typedef ShareInputResult = ({String? code, ShareInputError? error});

ShareInputResult classifyShareInput(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return (code: null, error: ShareInputError.empty);
  if (parseShareCode(raw) == null) {
    return (code: null, error: ShareInputError.invalidFormat);
  }
  return (code: raw.toLowerCase(), error: null);
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

String _slugifyClass(String classCode) => classCode
    .toLowerCase()
    .replaceAll(" ", "")
    .replaceAll("’", "")
    .replaceAll("'", "");
