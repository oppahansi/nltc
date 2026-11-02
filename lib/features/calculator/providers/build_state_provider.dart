// Package Imports
import "package:riverpod_annotation/riverpod_annotation.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/data_repo.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/talent_build/build_point.dart";
import "package:ltc/core/talent_build/class_build.dart";
import "package:ltc/core/talent_build/class_builds_repo.dart";
import "package:ltc/core/talent_build/saved_builds_provider.dart";
import "package:ltc/core/talent_build/share_util.dart";
import 'package:ltc/core/settings/settings_service_provider.dart';
import "package:ltc/features/calculator/logic/talent_rules.dart"
    as talent_rules;

part "build_state_provider.g.dart";

@Riverpod(keepAlive: true)
class BuildState extends _$BuildState {
  final _buildsRepo = ClassBuildsRepo();

  ClassBuild? _preloadedBuild;

  @override
  Future<ClassBuild> build() async {
    ref.listen(settingsProvider, (prev, next) {
      final prevCode = prev?.value?.locale.languageCode;
      final newCode = next.hasValue ? next.value!.locale.languageCode : null;
      if (newCode != null && prevCode != null && newCode != prevCode) {
        relocalize(newCode);
      }
    });

    if (_preloadedBuild != null) {
      final b = _preloadedBuild!;
      _preloadedBuild = null;
      return b;
    }

    final settings = ref.watch(settingsProvider).value!;

    final selectedExp = settings.selectedExp;
    final selectedClass = settings.selectedClass;

    final empty = await _createEmptyBuild(
      expansion: selectedExp,
      clazz: selectedClass,
    );

    final current = state.value;
    if (_preloadedBuild != null) {
      final b = _preloadedBuild!;
      _preloadedBuild = null;

      return b;
    } else if (current != null &&
        (current.buildSequence.isNotEmpty ||
            current.pointsSpentPerTree.any((p) => p > 0) ||
            current.talentRanks.isNotEmpty)) {
      return current;
    }

    return empty;
  }

  Future<ClassBuild> _createEmptyBuild({
    required Expansion expansion,
    required Class clazz,
  }) async {
    final settings = ref.read(settingsProvider).value!;
    final repo = DataRepo();
    final talentTrees =
        await repo.getTalentTrees(
            expansionId: expansion.id,
            classId: clazz.id,
            languageCode: settings.locale.languageCode,
          )
          ..sort((a, b) => a.id.compareTo(b.id));
    final treeTalents = <List<Talent>>[];
    final talentsMap = await repo.getTalents(
      expansionId: expansion.id,
      classId: clazz.id,
      languageCode: settings.locale.languageCode,
    );

    final talentTreeIds = talentsMap.keys.toList()..sort();

    for (var talentTreeId in talentTreeIds) {
      treeTalents.add(talentsMap[talentTreeId]!);
    }

    return ClassBuild(
      id: null,
      title: "${clazz.names[settings.locale.languageCode]} (0/0/0)",
      expansionId: expansion.id,
      expansionCode: expansion.code,
      classId: clazz.id,
      className:
          clazz.names[settings.locale.languageCode] ?? clazz.names.values.first,
      talentTrees: talentTrees,
      talentTreeTalents: treeTalents,
      talentRanks: {},
      buildSequence: [],
      pointsSpentPerTree: List.filled(talentTrees.length, 0),
    );
  }

  Future<void> loadSavedBuild(int id) async {
    final saved = await _buildsRepo.fetch(id);
    if (saved == null) return;

    _preloadedBuild = saved;
    state = AsyncData(saved);
  }

  Future<void> startNewBuild() async {
    final settings = ref.read(settingsProvider).value!;
    final selectedExp = settings.selectedExp;
    final selectedClass = settings.selectedClass;
    final empty = await _createEmptyBuild(
      expansion: selectedExp,
      clazz: selectedClass,
    );

    state = AsyncData(empty);
  }

  Future<int> saveBuild(String title) async {
    final current = state.value;
    if (current == null) {
      throw StateError("No active build");
    }

    final refreshedTalentRanks = <String, int>{
      for (final t in current.talentTreeTalents.expand((v) => v))
        if (t.currentRank > 0) "${t.id}": t.currentRank,
    };

    final buildToSave = current.copyWith(
      title: title,
      talentRanks: refreshedTalentRanks,
    );

    final id = await _buildsRepo.upsert(buildToSave);
    state = AsyncValue.data(buildToSave.copyWith(id: id));
    ref.invalidate(savedBuildsProvider);
    return id;
  }

  Future<void> deleteBuild(int buildId) async {
    await _buildsRepo.delete(buildId);

    if (state.value?.id == buildId) {
      ref.invalidateSelf();
    }

    ref.invalidate(savedBuildsProvider);
  }

  Future<void> resetBuild() async {
    final classBuild = state.value!;
    // Reset all talent ranks
    for (final talents in classBuild.talentTreeTalents) {
      for (final t in talents) {
        t.currentRank = 0;
      }
    }
    classBuild.buildSequence.clear();
    classBuild.pointsSpentPerTree = List.filled(
      classBuild.talentTreeTalents.length,
      0,
    );
    state = AsyncData(
      classBuild.copyWith(
        title: classBuild.title,
        talentTrees: classBuild.talentTrees,
        talentTreeTalents: classBuild.talentTreeTalents,
        buildSequence: classBuild.buildSequence,
        pointsSpentPerTree: classBuild.pointsSpentPerTree,
      ),
    );
  }

  void addPoint(Talent talent) {
    final classBuild = state.value!;

    if (!isTalentEnabled(talent)) return;
    if (talent.currentRank >= talent.ranks.length) return;

    talent.currentRank++;
    classBuild.buildSequence.add(
      BuildPoint(
        id: null,
        classBuildId: classBuild.id ?? 0,
        treeId: talent.talentTreeId,
        talentId: talent.id,
        order: classBuild.buildSequence.length,
      ),
    );
    classBuild.pointsSpentPerTree[talent.talentTreeId]++;

    state = AsyncData(
      classBuild.copyWith(
        title: classBuild.title,
        talentTrees: classBuild.talentTrees,
        talentTreeTalents: classBuild.talentTreeTalents,
        buildSequence: classBuild.buildSequence,
        pointsSpentPerTree: classBuild.pointsSpentPerTree,
      ),
    );
  }

  void removeLastPoint() {
    final classBuild = state.value!;
    if (classBuild.buildSequence.isEmpty) {
      return;
    }

    final lastBuildPoint = classBuild.buildSequence.last;
    final lastTalent = classBuild.talentTreeTalents
        .expand((t) => t)
        .firstWhere((t) => t.id == lastBuildPoint.talentId);

    if (lastTalent.currentRank > 0) {
      lastTalent.currentRank--;
    }

    classBuild.buildSequence.removeLast();
    classBuild.pointsSpentPerTree[lastTalent.talentTreeId] =
        (classBuild.pointsSpentPerTree[lastTalent.talentTreeId] - 1).clamp(
          0,
          999,
        );

    state = AsyncData(
      classBuild.copyWith(
        title: classBuild.title,
        talentTrees: classBuild.talentTrees,
        talentTreeTalents: classBuild.talentTreeTalents,
        buildSequence: classBuild.buildSequence,
        pointsSpentPerTree: classBuild.pointsSpentPerTree,
      ),
    );
  }

  void removePoint(Talent talent) {
    final classBuild = state.value!;
    if (classBuild.buildSequence.isEmpty) {
      return;
    }

    // Find the last occurrence of this talent in the build sequence
    final index = classBuild.buildSequence.lastIndexWhere(
      (bp) => bp.talentId == talent.id,
    );
    if (index == -1) {
      return; // Talent not found in build sequence
    }

    if (talent.currentRank > 0) {
      talent.currentRank--;
    }

    classBuild.buildSequence.removeAt(index);
    classBuild.pointsSpentPerTree[talent.talentTreeId] =
        (classBuild.pointsSpentPerTree[talent.talentTreeId] - 1).clamp(0, 999);

    state = AsyncData(
      classBuild.copyWith(
        title: classBuild.title,
        talentTrees: classBuild.talentTrees,
        talentTreeTalents: classBuild.talentTreeTalents,
        buildSequence: classBuild.buildSequence,
        pointsSpentPerTree: classBuild.pointsSpentPerTree,
      ),
    );
  }

  bool isTalentEnabled(Talent talent) =>
      talent_rules.isTalentEnabled(state.value!, talent);

  Talent? getLastTalent() {
    final classBuild = state.value!;
    if (classBuild.buildSequence.isEmpty) {
      return null;
    }

    final lastPoint = classBuild.buildSequence.last;
    final talent = classBuild.talentTreeTalents.expand((t) => t);
    return talent.firstWhere((t) => t.id == lastPoint.talentId);
  }

  bool canRemovePoint({Talent? talent}) {
    talent ??= getLastTalent();
    if (talent == null) return false;
    return talent_rules.canRemovePoint(state.value!, talent);
  }

  void updateBuildTitle(String value) {
    final classBuild = state.value!;
    classBuild.title = value;
    state = AsyncData(
      classBuild.copyWith(
        title: classBuild.title,
        talentTrees: classBuild.talentTrees,
        talentTreeTalents: classBuild.talentTreeTalents,
        buildSequence: classBuild.buildSequence,
        pointsSpentPerTree: classBuild.pointsSpentPerTree,
      ),
    );
  }

  String getBuildTitle() {
    final classBuild = state.value!;
    return classBuild.title;
  }

  bool isBuildSequenceEmpty() {
    final classBuild = state.value!;
    return classBuild.buildSequence.isEmpty;
  }

  List<int> getPointsSpentPerTree() {
    final classBuild = state.value!;
    return classBuild.pointsSpentPerTree;
  }

  bool isSkillTreeEmpty() {
    final classBuild = state.value!;
    return classBuild.talentTreeTalents.every(
      (talents) => talents.every((t) => t.currentRank == 0),
    );
  }

  Future<bool> importFromShareCode(String code) async {
    final parsed = parseShareCode(code);
    if (parsed == null) return false;

    // Load talents for expansion/class (assuming repository methods exist).
    final expansionId = expansionsToIds[parsed.expansion];
    final classId = classNamesToIds[parsed.classCode];
    if (expansionId == null || classId == null) return false;
    final dataRepo = DataRepo();
    final settings = ref.read(settingsProvider).value!;

    // Fetch base data (replace with actual repo/provider calls in your codebase).
    final trees = await dataRepo.getTalentTrees(
      expansionId: expansionId,
      classId: classId,
      languageCode: settings.locale.languageCode,
    );

    final talents = await dataRepo.getTalents(
      expansionId: expansionId,
      classId: classId,
      languageCode: settings.locale.languageCode,
    );

    final treeTalents = <List<Talent>>[];

    final talentTreeIds = talents.keys.toList()..sort();
    for (var k in talentTreeIds) {
      List<Talent> ts = talents[k]!;

      ts.sort((a, b) {
        final rowComp = a.row.compareTo(b.row);
        if (rowComp != 0) return rowComp;
        return a.column.compareTo(b.column);
      });

      treeTalents.add(ts);
    }

    if (treeTalents.length < 3 || parsed.trees.length > treeTalents.length) {
      return false;
    }
    trees.sort((a, b) => a.id.compareTo(b.id));
    for (int ti = 0; ti < parsed.trees.length; ti++) {
      final codeStr = parsed.trees[ti];
      final talents = treeTalents[ti];
      if (codeStr.length > talents.length) return false;
      for (int i = 0; i < codeStr.length; i++) {
        final digit = int.tryParse(codeStr[i]) ?? 0;
        talents[i].currentRank = digit.clamp(0, talents[i].ranks.length);
      }
    }

    final pointsPerTree = [
      for (final list in treeTalents)
        list.fold<int>(0, (s, t) => s + t.currentRank),
    ];

    final classes = await dataRepo.getClassesByExpansion(
      expansionId,
      languageCode: settings.locale.languageCode,
    );
    final className =
        classes
            .where((c) => c.id == classId)
            .firstOrNull
            ?.names[settings.locale.languageCode] ??
        parsed.classCode;
    final build = ClassBuild(
      id: null,
      title: "",
      expansionId: expansionId,
      expansionCode: parsed.expansion,
      classId: classId,
      className: className,
      talentTrees: trees,
      talentTreeTalents: treeTalents,
      talentRanks: {},
      buildSequence: [],
      pointsSpentPerTree: pointsPerTree,
    );

    if (parsed.order != null && !_replayOrder(build, parsed.order!)) {
      return false;
    }

    _preloadedBuild = build;
    state = AsyncData(build);
    return true;
  }

  /// Spends a shared order's points on an empty [build], following the rules as
  /// if they were tapped in. False if the order isn't a legal one.
  bool _replayOrder(ClassBuild build, List<int> order) {
    final talents = talentsInShareOrder(build.talentTreeTalents);
    for (final index in order) {
      if (index >= talents.length) return false;
      final talent = talents[index];
      if (talent.currentRank >= talent.ranks.length) return false;
      if (!talent_rules.isTalentEnabled(build, talent)) return false;

      talent.currentRank++;
      build.pointsSpentPerTree[talent.talentTreeId]++;
      build.buildSequence.add(
        BuildPoint(
          id: null,
          classBuildId: 0,
          treeId: talent.talentTreeId,
          talentId: talent.id,
          order: build.buildSequence.length,
        ),
      );
    }
    return true;
  }

  Future<void> relocalize(String langCode) async {
    if (!state.hasValue) return;
    final current = state.value!;
    try {
      final repo = DataRepo();

      final newTalentTrees = await repo.getTalentTrees(
        expansionId: current.expansionId,
        classId: current.classId,
        languageCode: langCode,
      );

      final newTalentsMap = await repo.getTalents(
        expansionId: current.expansionId,
        classId: current.classId,
        languageCode: langCode,
      );

      final oldTalentsById = <int, Talent>{};
      for (final list in current.talentTreeTalents) {
        for (final t in list) {
          oldTalentsById[t.id] = t;
        }
      }

      final mergedTalentTreeTalents = <List<Talent>>[];
      // Ensure deterministic order by talentTreeId
      final sortedEntries = newTalentsMap.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      for (final entry in sortedEntries) {
        final list = entry.value;
        for (final t in list) {
          final old = oldTalentsById[t.id];
          if (old != null) {
            t.currentRank = old.currentRank;
          }
        }
        for (final t in list) {
          t.supports = list.where((x) => x.dependencyId == t.id).toList();
        }
        mergedTalentTreeTalents.add(list);
      }

      final newSequence = <BuildPoint>[
        for (final bp in current.buildSequence)
          if (oldTalentsById.containsKey(bp.talentId)) bp,
      ];

      state = AsyncData(
        current.copyWith(
          title: current.title,
          talentTrees: newTalentTrees,
          talentTreeTalents: mergedTalentTreeTalents,
          buildSequence: newSequence,
        ),
      );

      // Update localized title WITHOUT deep cloning talents again (which would drop supports)
      final pointsSummary = _pointsSummaryString(current.pointsSpentPerTree);
      final localizedClassName = current.className;
      // mutate title directly
      state.value!.title = "$localizedClassName $pointsSummary";
      // re-emit to notify listeners
      state = AsyncData(state.value!);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  String _pointsSummaryString(List<int> pts) {
    final first = pts.isNotEmpty ? pts[0] : 0;
    final second = pts.length > 1 ? pts[1] : 0;
    final third = pts.length > 2 ? pts[2] : 0;
    return "($first/$second/$third)";
  }
}
