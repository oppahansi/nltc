// Dart Imports
import "dart:convert";
import "dart:ui";

// Project Imports
import "package:ltc/core/models/data_entities.dart";
import "package:ltc/core/services/settings_service.dart";
import "package:ltc/core/utils/colors.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/features/calculator/models/build_point.dart";

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
    };
  }

  static ClassBuild fromDbRow(
    Map<String, Object?> row, {
    required List<TalentTree> talentTrees,
    required List<List<Talent>> talentTreeTalents,
    List<BuildPoint> buildSequence = const [],
  }) {
    final settings = SettingsService.getSettings();
    // Apply buildPoints to talents to reconstruct current ranks + points per tree.
    final pointsPerTree = List<int>.filled(talentTrees.length, 0);

    // Decode talentRanks map (may contain normalized keys)
    final decodedTalentRanks = (row["talent_ranks"] != null)
        ? Map<String, dynamic>.from(
            jsonDecode(row["talent_ranks"] as String),
          ).map((k, v) => MapEntry(k, (v as num).toInt()))
        : <String, int>{};

    if (buildSequence.isNotEmpty) {
      // Map talentId -> Talent reference
      final talentMap = {
        for (final t in talentTreeTalents.expand((v) => v)) t.id: t,
      };
      for (final bp in buildSequence) {
        final t = talentMap[bp.talentId];
        if (t != null) {
          t.currentRank = (t.currentRank + 1).clamp(0, t.ranks.length);
          pointsPerTree[t.talentTreeId] += 1;
        }
      }
    } else if (decodedTalentRanks.isNotEmpty) {
      // Fallback: no sequence -> apply ranks from talentRanks
      String norm(String s) =>
          s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]"), "");
      final normalizedMap = <String, int>{
        for (final e in decodedTalentRanks.entries) norm(e.key): e.value,
      };
      for (final talent in talentTreeTalents.expand((v) => v)) {
        final r = normalizedMap[talent.names[settings.locale.languageCode]];
        if (r != null && r > 0) {
          final applied = r.clamp(0, talent.ranks.length);
          talent.currentRank = applied;
          pointsPerTree[talent.talentTreeId] =
              (pointsPerTree[talent.talentTreeId] + applied).clamp(0, 999);
        }
      }
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
    );
  }

  ClassBuild copyWith({
    int? id,
    String? title,
    List<TalentTree>? talentTrees,
    List<List<Talent>>? talentTreeTalents,
    Map<String, int>? talentRanks,
    List<BuildPoint>? buildSequence,
    List<int>? pointsSpentPerTree,
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
    );
  }

  Color getClassColor() {
    return classColors[className.toLowerCase().replaceAll(" ", "")]!.toColor();
  }
}
