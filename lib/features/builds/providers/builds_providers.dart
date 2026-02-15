// Package Imports
import "package:riverpod_annotation/riverpod_annotation.dart";

// Project Imports
import "package:ltc/core/models/data_entities.dart";
import "package:ltc/core/providers/settings_service_provider.dart";
import "package:ltc/core/repos/data_providers.dart";
import "package:ltc/core/repos/data_repo.dart";
import "package:ltc/features/builds/models/builds_entities.dart";
import "package:ltc/features/builds/services/battlenet_service.dart";
import "package:ltc/features/calculator/models/class_build.dart";

part "builds_providers.g.dart";

@Riverpod(keepAlive: true)
class SelectedRegion extends _$SelectedRegion {
  @override
  String build() => "us";
  void setRegion(String value) => state = value;
}

@riverpod
Future<List<Realm>> realms(Ref ref, String region) async {
  final api = BattleNetApiService();
  if (region.isEmpty) return [];
  return api.fetchRealms(region: region);
}

@Riverpod(keepAlive: true)
class SelectedRealm extends _$SelectedRealm {
  @override
  String? build() => null;
  void setRealm(String? value) => state = value;
  void clear() => state = null;
}

@Riverpod(keepAlive: true)
class SelectedCharName extends _$SelectedCharName {
  @override
  String build() => "";
  void setName(String value) => state = value;
}

@Riverpod(keepAlive: true)
class RemoteClassBuilds extends _$RemoteClassBuilds {
  final _api = BattleNetApiService();

  @override
  AsyncValue<List<ClassBuild>> build() {
    ref.listen(settingsProvider, (prev, next) {
      final prevCode = prev?.value?.locale.languageCode;
      final newCode = next.hasValue ? next.value!.locale.languageCode : null;
      if (prevCode != null && newCode != null && prevCode != newCode) {
        if (state.hasValue && state.value!.isNotEmpty) {
          refresh();
        }
      }
    });
    return const AsyncValue.data([]);
  }

  Future<void> refresh() async {
    final region = ref.read(selectedRegionProvider);
    final server = ref.read(selectedRealmProvider);
    final name = ref.read(selectedCharNameProvider);

    state = const AsyncValue.loading();

    try {
      final settings = ref.watch(settingsProvider).value!;
      final currentLang = settings.locale.languageCode;
      final repo = DataRepo();

      // 1. API (English names)
      final remoteResponse = await _api.fetchClassBuilds(
        region: region,
        server: server ?? "",
        characterName: name,
      );
      if (remoteResponse.builds.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      // 2. Class resolution (English list for match, localized list for UI)
      final classesEnglish = await repo.getClassesByExpansion(
        1,
        languageCode: "en",
      );
      final classesLocalized = await ref.watch(classesProvider.future);
      if (classesEnglish.isEmpty || classesLocalized.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      final englishClass = classesEnglish.firstWhere(
        (c) =>
            (c.names["en"] ?? "").toLowerCase() ==
            remoteResponse.className.toLowerCase(),
        orElse: () => classesEnglish.first,
      );
      final localizedClass = classesLocalized.firstWhere(
        (c) => c.id == englishClass.id,
        orElse: () => classesLocalized.first,
      );

      // 3. Fetch English & Localized talent data (trees + talents)
      final englishTrees = await repo.getTalentTrees(
        expansionId: 1,
        classId: englishClass.id,
        languageCode: "en",
      );
      final englishTalentsMap = await repo.getTalents(
        expansionId: 1,
        classId: englishClass.id,
        languageCode: "en",
      );

      final localizedTrees = await repo.getTalentTrees(
        expansionId: 1,
        classId: localizedClass.id,
        languageCode: currentLang,
      );
      final localizedTalentsMap = await repo.getTalents(
        expansionId: 1,
        classId: localizedClass.id,
        languageCode: currentLang,
      );

      if (englishTrees.isEmpty ||
          englishTalentsMap.isEmpty ||
          localizedTrees.isEmpty ||
          localizedTalentsMap.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      // Tree lookup helpers
      String norm(String s) => s.toLowerCase().trim();
      final englishTreeByName = {
        for (final t in englishTrees) norm(t.names["en"] ?? ""): t,
      };
      final englishTreeIndexById = <int, int>{
        for (var i = 0; i < localizedTrees.length; i++) localizedTrees[i].id: i,
      };

      // Talent lookup (per tree) in English
      final englishTalentByNamePerTree = <int, Map<String, Talent>>{
        for (final entry in englishTalentsMap.entries)
          entry.key: {
            for (final t in entry.value) norm(t.names["en"] ?? ""): t,
          },
      };

      final result = <ClassBuild>[];

      for (final remoteSpec in remoteResponse.builds) {
        // Reset all english current ranks
        for (final list in englishTalentsMap.values) {
          for (final t in list) {
            t.currentRank = 0;
          }
        }

        final pointsSpentPerTree = List<int>.filled(localizedTrees.length, 0);

        // Apply ranks using ENGLISH names
        for (final remoteTreeName in remoteSpec.talentTreeTalents.keys) {
          final englishTree =
              englishTreeByName[norm(remoteTreeName)] ?? englishTrees.first;
          final remoteTalents =
              remoteSpec.talentTreeTalents[remoteTreeName] ?? const {};

          final englishTalents =
              englishTalentsMap[englishTree.id] ?? const <Talent>[];

          final treeTalentByName =
              englishTalentByNamePerTree[englishTree.id] ?? const {};

          final treeIdx = englishTreeIndexById[englishTree.id] ?? 0;

          for (final remoteTalentName in remoteTalents.keys) {
            final englishTalent =
                treeTalentByName[norm(remoteTalentName)] ??
                (englishTalents.isNotEmpty ? englishTalents.first : null);
            if (englishTalent == null) continue;
            final rank = remoteTalents[remoteTalentName]!.clamp(
              0,
              englishTalent.ranks.length,
            );
            englishTalent.currentRank = rank;
            pointsSpentPerTree[treeIdx] += rank;
          }
        }

        // Copy ranks to localized talents by id
        for (final entry in localizedTalentsMap.entries) {
          final localizedList = entry.value;
          final englishList = englishTalentsMap[entry.key] ?? const <Talent>[];
          final englishById = {for (final t in englishList) t.id: t};
          for (final lt in localizedList) {
            final et = englishById[lt.id];
            if (et != null) lt.currentRank = et.currentRank;
          }
        }

        // Build localized talents snapshot (deep copy)
        final specTalentsSnapshot = <List<Talent>>[
          for (final tree in localizedTrees)
            [
              for (final t in (localizedTalentsMap[tree.id] ?? []))
                t.copyWith(),
            ],
        ];

        // Recompute supports within snapshot
        final all = specTalentsSnapshot.expand((l) => l).toList();
        for (final t in all) {
          t.supports = all.where((o) => o.dependencyId == t.id).toList();
        }

        // Localize title: translate remote tree English names to localized names
        final localizedTreeNameById = {
          for (final t in localizedTrees)
            t.id: (t.names[currentLang] ?? t.names.values.first),
        };
        final englishTreeNameToLocalized = {
          for (final et in englishTrees)
            (et.names["en"] ?? ""):
                localizedTreeNameById[et.id] ?? (et.names["en"] ?? ""),
        };
        final specTitleKeys = remoteSpec.talentTreeTalents.keys
            .map((k) => englishTreeNameToLocalized[k] ?? k)
            .toList();

        final dist = pointsSpentPerTree.join("/");
        final title = specTitleKeys.isNotEmpty
            ? "${specTitleKeys.join(" / ")} ($dist)"
            : "Spec ($dist)";

        // TalentRanks map uses localized names (currentLang) for persistence
        final talentRanks = <String, int>{
          for (final t in all)
            if (t.currentRank > 0)
              (t.names[currentLang] ?? t.names.values.first): t.currentRank,
        };

        result.add(
          ClassBuild(
            id: null,
            title: title,
            expansionId: 1,
            expansionCode: "vanilla",
            classId: localizedClass.id,
            className:
                localizedClass.names[currentLang] ??
                localizedClass.names.values.first,
            talentTrees: localizedTrees,
            talentTreeTalents: specTalentsSnapshot,
            talentRanks: talentRanks,
            buildSequence: [],
            pointsSpentPerTree: pointsSpentPerTree,
          ),
        );
      }

      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.data([]);
  }
}
