// Dart Imports
import "dart:convert";
import "dart:io";

// Package Imports
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

// Project Imports
import "package:ltc/core/db/db.dart";
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/settings/setting_keys.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/talent_build/class_build.dart";
import "package:ltc/core/talent_build/class_builds_repo.dart";
import "package:ltc/core/talent_build/share_util.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";

// Relative Project Imports
import "../../helpers/test_db.dart";

const vanilla = 1;
const tbc = 2;
const wotlk = 3;
const druid = 0;
const mage = 2;

void main() {
  late Directory dir;
  late ProviderContainer container;

  BuildState notifier() => container.read(buildStateProvider.notifier);
  ClassBuild build() => container.read(buildStateProvider).value!;
  Iterable<Talent> talents() => build().talentTreeTalents.expand((t) => t);
  Talent talent(int id) => talents().firstWhere((t) => t.id == id);
  int total() => build().pointsSpentPerTree.reduce((a, b) => a + b);

  Future<void> set(String key, String value) =>
      container.read(settingsProvider.notifier).setSetting(key, value);

  Future<void> select(int expansionId, int classId) async {
    await set(settingsKeySelectedExpId, "$expansionId");
    await set(settingsKeySelectedClassId, "$classId");
    await container.read(buildStateProvider.future);
    await notifier().startNewBuild();
  }

  Talent firstInTree(int tree) =>
      build().talentTreeTalents[tree].firstWhere((t) => t.row == 0);

  setUp(() async {
    dir = await setUpTestDb();
    container = ProviderContainer();
    await container.read(settingsProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDb(dir);
  });

  group("talent rules", () {
    setUp(() => select(vanilla, mage));

    test("a talent can't take more points than it has ranks", () {
      final t = firstInTree(0);
      for (var i = 0; i < t.ranks.length + 2; i++) {
        notifier().addPoint(talent(t.id));
      }
      expect(talent(t.id).currentRank, t.ranks.length);
      expect(total(), t.ranks.length);
    });

    test("deeper rows need five points per row in that tree", () {
      final deeper = build().talentTreeTalents[0].firstWhere(
        (t) => t.row == 1 && t.dependencyId == null,
      );
      expect(notifier().isTalentEnabled(deeper), isFalse);

      var added = 0;
      for (final t in build().talentTreeTalents[0].where((t) => t.row == 0)) {
        for (var i = 0; i < t.ranks.length && added < 5; i++) {
          notifier().addPoint(talent(t.id));
          added++;
        }
      }
      expect(added, 5);
      expect(notifier().isTalentEnabled(talent(deeper.id)), isTrue);
    });

    test("undoing is blocked when it would invalidate a deeper talent", () {
      final points = <int>[];
      for (final t in build().talentTreeTalents[0].where((t) => t.row == 0)) {
        for (var i = 0; i < t.ranks.length && points.length < 5; i++) {
          notifier().addPoint(talent(t.id));
          points.add(t.id);
        }
      }
      final deeper = build().talentTreeTalents[0].firstWhere(
        (t) => t.row == 1 && t.dependencyId == null,
      );
      notifier().addPoint(talent(deeper.id));

      expect(notifier().canRemovePoint(talent: talent(points.last)), isFalse);
      expect(notifier().canRemovePoint(talent: talent(deeper.id)), isTrue);

      notifier().removeLastPoint();
      expect(talent(deeper.id).currentRank, 0);
      expect(total(), 5);
    });

    test("reset clears points and the sequence", () async {
      notifier().addPoint(firstInTree(0));
      await notifier().resetBuild();
      expect(total(), 0);
      expect(build().buildSequence, isEmpty);
      expect(talents().every((t) => t.currentRank == 0), isTrue);
    });
  });

  group("saving and loading", () {
    setUp(() => select(vanilla, mage));

    test("loading a saved build doesn't double count its points", () async {
      final t = firstInTree(0);
      notifier().addPoint(t);
      notifier().addPoint(talent(t.id));
      final id = await notifier().saveBuild("two points");

      await notifier().startNewBuild();
      await notifier().loadSavedBuild(id);

      expect(talent(t.id).currentRank, 2);
      expect(build().pointsSpentPerTree, [2, 0, 0]);
      expect(build().buildSequence.length, 2);
    });

    test("a saved build keeps its ranks after switching language", () async {
      final t = firstInTree(1);
      notifier().addPoint(t);
      final id = await notifier().saveBuild("language");

      await set(settingsKeyLocale, "de");
      await notifier().loadSavedBuild(id);

      expect(talent(t.id).currentRank, 1);
      expect(total(), 1);
    });

    test(
      "a share code from a saved build survives a language switch",
      () async {
        final t = firstInTree(1);
        notifier().addPoint(t);
        final expected = buildShareCode(build());
        await notifier().saveBuild("share");
        final id = build().id!;

        await set(settingsKeyLocale, "de");
        await notifier().loadSavedBuild(id);

        expect(buildShareCode(build()), expected);
      },
    );

    test("talents sharing a German name keep separate ranks", () async {
      final db = await Db.getDataDbInstance();
      final colliding = await db.rawQuery("""
        SELECT t.classId c, MIN(t.id) a, MAX(t.id) b
        FROM talents t JOIN talent_names n ON n.talentId = t.id AND n.languageCode = 'de'
        WHERE t.expansion = 1 GROUP BY t.classId, n.name HAVING COUNT(*) > 1 LIMIT 1
      """);
      expect(colliding, isNotEmpty, reason: "this test needs a shared name");
      final row = colliding.first;

      await set(settingsKeyLocale, "de");
      await select(vanilla, row["c"] as int);
      // Set ranks directly: only the storage is under test here, and the rules
      // don't let every such pair be reached.
      talent(row["a"] as int).currentRank = 1;
      talent(row["b"] as int).currentRank = 2;
      final id = await notifier().saveBuild("collision");

      final saved = await (await Db.getUserDbInstance()).query(
        ClassBuild.tableName,
        where: "id=?",
        whereArgs: [id],
      );
      expect(jsonDecode(saved.first["talent_ranks"] as String), {
        "${row["a"]}": 1,
        "${row["b"]}": 2,
      });
    });

    test(
      "old saves keyed by talent name still load, in either language",
      () async {
        final db = await Db.getUserDbInstance();
        final t = firstInTree(1);
        final name = t.names["en"]!;
        final id = await db.insert(ClassBuild.tableName, {
          "title": "old",
          "expansion_id": vanilla,
          "expansion_code": "vanilla",
          "class_id": mage,
          "class_name": "Mage",
          "talent_ranks": jsonEncode({name: 2}),
          "talents_build_sequence": "[]",
        });

        await notifier().loadSavedBuild(id);
        expect(talent(t.id).currentRank, 2);
        expect(total(), 2);

        await set(settingsKeyLocale, "de");
        await notifier().loadSavedBuild(id);
        expect(talent(t.id).currentRank, 2);
        expect(total(), 2);
      },
    );

    test("old saves using a since corrected talent name still load", () async {
      for (final (name, expansion, code, classId) in [
        ("Unholy Frenzy", wotlk, "wotlk", 9),
        ("Unheilige Raserei", wotlk, "wotlk", 9),
        ("Verbesserte Sayaad", tbc, "tbc", 7),
      ]) {
        final id = await (await Db.getUserDbInstance()).insert(
          ClassBuild.tableName,
          {
            "title": "old",
            "expansion_id": expansion,
            "expansion_code": code,
            "class_id": classId,
            "class_name": "x",
            "talent_ranks": jsonEncode({name: 1}),
            "talents_build_sequence": "[]",
          },
        );
        await notifier().loadSavedBuild(id);
        expect(total(), 1, reason: name);
      }
    });

    test(
      "a save from a newer version's expansion doesn't crash the list",
      () async {
        final id = await (await Db.getUserDbInstance()).insert(
          ClassBuild.tableName,
          {
            "title": "from the future",
            "expansion_id": 99,
            "expansion_code": "unknown",
            "class_id": mage,
            "class_name": "Mage",
            "talent_ranks": "{}",
            "talents_build_sequence": "[]",
          },
        );
        final saved = await ClassBuildsRepo().fetch(id);
        expect(saved, isNotNull);
        expect(saved!.getClassColor, returnsNormally);
      },
    );
  });

  group("share codes", () {
    test("codes round trip for every expansion and class", () async {
      final db = await Db.getDataDbInstance();
      final pairs = await db.rawQuery(
        "SELECT DISTINCT t.expansion e, c.id c, c.code code FROM talents t "
        "JOIN classes c ON c.id = t.classId ORDER BY 1, 2",
      );
      expect(pairs.length, 9 + 9 + 10);
      for (final pair in pairs) {
        final expansion = const {
          1: "vanilla",
          2: "tbc",
          3: "wotlk",
        }[pair["e"]]!;
        final classCode = (pair["code"] as String).toLowerCase();
        final counts = await db.rawQuery(
          "SELECT COUNT(*) n FROM talents WHERE expansion = ? AND classId = ? "
          "GROUP BY talentTreeId ORDER BY talentTreeId",
          [pair["e"], pair["c"]],
        );
        final trees = [for (final c in counts) "1" * (c["n"] as int)];
        final code = "$expansion-$classCode-${trees.join("-")}";

        expect(
          await notifier().importFromShareCode(code),
          isTrue,
          reason: code,
        );
        expect(buildShareCode(build()), code);
        expect(total(), trees.join().length, reason: code);
      }
    });

    test(
      "classic codes parse, but don't import until their data exists",
      () async {
        expect(
          parseShareCode("classic_tbc-mage-1-2-3")?.expansion,
          "classic_tbc",
        );
        expect(parseShareCode("retail-mage-1-2-3"), isNull);
        expect(
          await notifier().importFromShareCode("classic_tbc-mage-1-2-3"),
          isFalse,
        );
      },
    );

    test("old codes shorter than the tree still import", () async {
      expect(
        await notifier().importFromShareCode("vanilla-mage-5-0-0"),
        isTrue,
      );
      final tree = [...build().talentTreeTalents[0]]
        ..sort((a, b) {
          final r = a.row.compareTo(b.row);
          return r != 0 ? r : a.column.compareTo(b.column);
        });
      expect(tree.first.currentRank, tree.first.ranks.length.clamp(0, 5));
    });

    test("invalid codes are rejected", () async {
      for (final code in [
        "",
        "nonsense",
        "cata-mage-1-2-3",
        "vanilla-mage-1-2",
        "vanilla-notaclass-1-2-3",
        "vanilla-mage-${"1" * 99}-0-0",
      ]) {
        expect(
          await notifier().importFromShareCode(code),
          isFalse,
          reason: code,
        );
      }
    });

    test("Wowhead links are built and read for tbc and wotlk only", () async {
      await select(tbc, mage);
      expect(
        buildShareUrl(build()),
        startsWith("https://www.wowhead.com/tbc/talent-calc/mage/"),
      );
      await select(wotlk, 9);
      expect(
        buildShareUrl(build()),
        startsWith("https://www.wowhead.com/wotlk/talent-calc/death-knight/"),
      );
      expect(
        normalizeShareInputToCode(
          "https://www.wowhead.com/wotlk/talent-calc/death-knight/1-2-3",
        ),
        "wotlk-deathknight-1-2-3",
      );
      await select(vanilla, mage);
      expect(canShareBuild(build()), isFalse);
    });

    test("sharing includes points added after loading a build", () async {
      await select(vanilla, mage);
      final t = firstInTree(0);
      notifier().addPoint(t);
      final id = await notifier().saveBuild("before");
      await notifier().loadSavedBuild(id);

      notifier().addPoint(talent(t.id));
      final code = buildShareCode(build());

      expect(talent(t.id).currentRank, 2);
      expect(
        code.split("-")[2].split("").map(int.parse).reduce((a, b) => a + b),
        2,
      );
    });

    test(
      "an imported build keeps its class, and can be saved and listed",
      () async {
        await notifier().importFromShareCode("vanilla-mage-05-0-0");
        expect(build().className, "Mage");

        final id = await notifier().saveBuild("imported");
        await notifier().loadSavedBuild(id);

        expect(build().getClassColor, returnsNormally);
        expect(total(), 5);
      },
    );

    test("the point cap follows the build, not the selected expansion", () async {
      await select(vanilla, druid);
      final db = await Db.getDataDbInstance();
      final rows = await db.rawQuery(
        "SELECT t.talentTreeId tree, t.id, COUNT(r.rank) ranks FROM talents t "
        "JOIN ranks r ON r.talentId = t.id WHERE t.expansion = 3 AND t.classId = ? "
        "GROUP BY t.id ORDER BY t.talentTreeId, t.row, t.column",
        [druid],
      );
      final digits = <int, StringBuffer>{
        0: StringBuffer(),
        1: StringBuffer(),
        2: StringBuffer(),
      };
      var spent = 0;
      for (final row in rows) {
        final rank = spent < 51
            ? (row["ranks"] as int).clamp(0, 51 - spent)
            : 0;
        digits[row["tree"]]!.write(rank);
        spent += rank;
      }
      expect(spent, 51);
      final code = "wotlk-druid-${digits[0]}-${digits[1]}-${digits[2]}";
      expect(await notifier().importFromShareCode(code), isTrue);

      final open = talents().firstWhere(
        (t) => t.row == 0 && t.currentRank == 0,
      );
      expect(notifier().isTalentEnabled(open), isTrue);
    });
  });
}
