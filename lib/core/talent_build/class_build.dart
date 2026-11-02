// Dart Imports
import "dart:convert";
import "dart:ui";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/game/game_colors.dart";
import "package:ltc/core/talent_build/build_point.dart";
import "package:ltc/core/utils/extensions.dart";

class ClassBuild {
  static const tableName = "class_builds";

  int? id;
  String title = "";
  final int expansionId;
  final String expansionCode;
  final int classId;
  final String className;
  final List<TalentTree> talentTrees;
  final List<List<Talent>> talentTreeTalents;
  final Map<String, int> talentRanks;
  final List<BuildPoint> buildSequence;

  /// In the order they were chosen. Only WotLK builds have any.
  final List<int> glyphIds;

  List<int> pointsSpentPerTree = [0, 0, 0];

  ClassBuild({
    this.id,
    required this.title,
    required this.expansionId,
    required this.expansionCode,
    required this.classId,
    required this.className,
    required this.talentTrees,
    required this.talentTreeTalents,
    required this.talentRanks,
    required this.buildSequence,
    required this.pointsSpentPerTree,
    this.glyphIds = const [],
  });

  Map<String, dynamic> toDbMap() {
    return {
      "id": id,
      "title": title,
      "expansion_id": expansionId,
      "expansion_code": expansionCode,
      "class_id": classId,
      "class_name": className,
      "talent_ranks": jsonEncode(talentRanks),
      // Persist sequence of talentIds (order) for quick preview; build_points table stores full detail.
      "talents_build_sequence": jsonEncode(
        buildSequence.map((bp) => bp.talentId).toList(),
      ),
      "glyphs": jsonEncode(glyphIds),
    };
  }

  static ClassBuild fromDbRow(
    Map<String, Object?> row, {
    required List<TalentTree> talentTrees,
    required List<List<Talent>> talentTreeTalents,
    List<BuildPoint> buildSequence = const [],
    Map<String, int> talentIdsByName = const {},
  }) {
    final decodedTalentRanks = _decodeTalentRanks(
      row["talent_ranks"] as String?,
      talentIdsByName,
    );

    final talentsById = {
      for (final t in talentTreeTalents.expand((v) => v)) t.id: t,
    };
    if (buildSequence.isNotEmpty) {
      for (final bp in buildSequence) {
        final t = talentsById[bp.talentId];
        if (t != null) {
          t.currentRank = (t.currentRank + 1).clamp(0, t.ranks.length);
        }
      }
    } else {
      // Imported builds have no sequence, only ranks.
      decodedTalentRanks.forEach((key, rank) {
        final t = talentsById[int.parse(key)];
        if (t != null) t.currentRank = rank.clamp(0, t.ranks.length);
      });
    }

    final pointsPerTree = List<int>.filled(talentTrees.length, 0);
    for (final t in talentsById.values) {
      pointsPerTree[t.talentTreeId] += t.currentRank;
    }

    return ClassBuild(
      id: row["id"] as int?,
      title: row["title"] as String? ?? "",
      expansionId: row["expansion_id"] as int,
      expansionCode: row["expansion_code"] as String,
      classId: row["class_id"] as int,
      className: row["class_name"] as String,
      talentRanks: decodedTalentRanks,
      talentTrees: talentTrees,
      talentTreeTalents: talentTreeTalents,
      buildSequence: buildSequence,
      pointsSpentPerTree: pointsPerTree,
      glyphIds: (jsonDecode(row["glyphs"] as String? ?? "[]") as List)
          .cast<int>(),
    );
  }

  /// Ranks are stored by talent id. Saves from older versions used the talent's
  /// localized name instead, so those are translated through [talentIdsByName].
  static Map<String, int> _decodeTalentRanks(
    String? json,
    Map<String, int> talentIdsByName,
  ) {
    if (json == null) return {};
    final ranks = <String, int>{};
    (jsonDecode(json) as Map<String, dynamic>).forEach((key, value) {
      final id = int.tryParse(key) ?? talentIdsByName[key];
      if (id != null) ranks["$id"] = (value as num).toInt();
    });
    return ranks;
  }

  ClassBuild copyWith({
    int? id,
    String? title,
    List<TalentTree>? talentTrees,
    List<List<Talent>>? talentTreeTalents,
    Map<String, int>? talentRanks,
    List<BuildPoint>? buildSequence,
    List<int>? pointsSpentPerTree,
    List<int>? glyphIds,
  }) {
    return ClassBuild(
      id: id ?? this.id,
      title: title ?? this.title,
      expansionId: expansionId,
      expansionCode: expansionCode,
      classId: classId,
      className: className,
      talentTrees:
          talentTrees ?? this.talentTrees.map((t) => t.copyWith()).toList(),
      talentTreeTalents:
          talentTreeTalents ??
          this.talentTreeTalents
              .map((list) => list.map((t) => t.copyWith()).toList())
              .toList(),
      talentRanks: talentRanks ?? Map<String, int>.from(this.talentRanks),
      buildSequence:
          buildSequence ??
          this.buildSequence.map((bp) => bp.copyWith()).toList(),
      pointsSpentPerTree:
          pointsSpentPerTree ?? List<int>.from(this.pointsSpentPerTree),
      glyphIds: glyphIds ?? this.glyphIds,
    );
  }

  Color getClassColor() {
    return classColors[idsToClasses[classId]]!.toColor();
  }
}
