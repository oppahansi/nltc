// Dart Imports
import "dart:core";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/talent_build/class_build.dart";

/// Share codes come in two forms, both starting with expansion and class:
///
/// - Ordered, like `tbc-mage-o0a1c2k`: the points in the order they were spent.
///   The ranks follow from that, so nothing else is needed.
/// - Ranks only, like `tbc-mage-05-0-0`: a digit per talent for each tree. Used
///   when a build has no complete order, such as one imported from this form.
String buildShareCode(ClassBuild build) {
  final exp = build.expansionCode.toLowerCase();

  // Stable internal class code
  final rawClassCode =
      idsToClasses[build.classId]?.toLowerCase() ??
      build.className.toLowerCase();
  final classCode = _slugifyClass(rawClassCode);
  final prefix = "$exp-$classCode";

  final order = _encodeOrder(build);
  if (order != null) {
    return "$prefix-$_orderMarker$order${_checksum("$prefix-$order")}";
  }

  final treeStrings = <String>[];
  for (var i = 0; i < build.talentTreeTalents.length; i++) {
    treeStrings.add(_encodeTree(build.talentTreeTalents[i]));
  }
  return "$prefix-${treeStrings.join("-")}";
}

class ParsedShareCode {
  final String expansion;
  final String classCode;

  /// A rank digit per talent, for 3 trees, or 6 with Forever's Legacy trees.
  /// Empty if the code has an [order].
  final List<String> trees;

  /// One entry per point in the order spent, as an index into
  /// [talentsInShareOrder]. Null if the code only has ranks.
  final List<int>? order;

  ParsedShareCode(this.expansion, this.classCode, this.trees, {this.order});
}

final _codeRegex = RegExp(
  r"^([a-z_]+)-([a-z]+)-([0-9]+)-([0-9]+)-([0-9]+)(?:-([0-9]+)-([0-9]+)-([0-9]+))?$",
);
final _orderedCodeRegex = RegExp(r"^([a-z_]+)-([a-z]+)-o([0-9a-v]+)$");

ParsedShareCode? parseShareCode(String code) {
  final normalized = code.trim().toLowerCase();
  final ordered = _orderedCodeRegex.firstMatch(normalized);
  if (ordered != null) return _parseOrderedCode(ordered);

  final m = _codeRegex.firstMatch(normalized);
  if (m == null) return null;
  final expansion = m.group(1)!;
  if (!expansionsToIds.containsKey(expansion)) return null;
  final cls = m.group(2)!;
  final trees = [for (var i = 3; i <= 8; i++) ?m.group(i)];
  return ParsedShareCode(expansion, cls, trees);
}

ParsedShareCode? _parseOrderedCode(RegExpMatch m) {
  final expansion = m.group(1)!;
  final cls = m.group(2)!;
  final payload = m.group(3)!;
  if (!expansionsToIds.containsKey(expansion)) return null;
  if (payload.length.isOdd || payload.length < _pairLength * 2) return null;

  final split = payload.length - _pairLength;
  final order = payload.substring(0, split);
  // Catches typos and pastes that were cut off, which would otherwise still
  // read as a valid, shorter build.
  if (payload.substring(split) != _checksum("$expansion-$cls-$order")) {
    return null;
  }
  return ParsedShareCode(expansion, cls, const [], order: _decodeOrder(order));
}

/// All of a build's talents in the order share codes refer to them.
List<Talent> talentsInShareOrder(List<List<Talent>> trees) => [
  for (final tree in trees) ..._sortedByPosition(tree),
];

// Each run of points on one talent takes a pair of base 32 characters, which
// survive messengers and changes of case: 7 bits for the talent, and 3 for the
// run length minus one. Base 32 needs nothing but lowercase letters and digits.
const _orderMarker = "o";
const _base32 = "0123456789abcdefghijklmnopqrstuv";
const _pairLength = 2;
const _maxRun = 8;
const _runBits = 3;

String _encodePair(int value) => "${_base32[value >> 5]}${_base32[value & 31]}";

int _decodePair(String text, int at) =>
    _base32.indexOf(text[at]) << 5 | _base32.indexOf(text[at + 1]);

/// Null if the sequence doesn't account for every rank, as with a build imported
/// from a ranks-only code.
String? _encodeOrder(ClassBuild build) {
  final sequence = build.buildSequence;
  if (sequence.isEmpty) return null;

  final talents = talentsInShareOrder(build.talentTreeTalents);
  final indexById = {for (var i = 0; i < talents.length; i++) talents[i].id: i};

  final spent = <int, int>{};
  for (final point in sequence) {
    spent.update(point.talentId, (v) => v + 1, ifAbsent: () => 1);
  }
  for (final talent in talents) {
    if ((spent[talent.id] ?? 0) != talent.currentRank) return null;
  }

  final out = StringBuffer();
  var i = 0;
  while (i < sequence.length) {
    final id = sequence[i].talentId;
    final index = indexById[id];
    if (index == null) return null;
    var run = 1;
    while (run < _maxRun &&
        i + run < sequence.length &&
        sequence[i + run].talentId == id) {
      run++;
    }
    out.write(_encodePair(index << _runBits | (run - 1)));
    i += run;
  }
  return out.toString();
}

List<int> _decodeOrder(String order) {
  final points = <int>[];
  for (var i = 0; i < order.length; i += _pairLength) {
    final value = _decodePair(order, i);
    final index = value >> _runBits;
    final run = (value & (_maxRun - 1)) + 1;
    points.addAll(List.filled(run, index));
  }
  return points;
}

/// FNV-1a, cut to one pair of characters.
String _checksum(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return _encodePair((hash ^ (hash >> 10)) & 0x3ff);
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

List<Talent> _sortedByPosition(List<Talent> talents) =>
    [...talents]..sort((a, b) {
      final r = a.row.compareTo(b.row);
      if (r != 0) return r;
      final c = a.column.compareTo(b.column);
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    });

String _encodeTree(List<Talent> talents) {
  final sb = StringBuffer();
  for (final t in _sortedByPosition(talents)) {
    sb.write(t.currentRank.clamp(0, 9));
  }
  return sb.toString();
}

String _slugifyClass(String classCode) => classCode
    .toLowerCase()
    .replaceAll(" ", "")
    .replaceAll("’", "")
    .replaceAll("'", "");
