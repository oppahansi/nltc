// Dart Imports
import "dart:convert";
import "dart:io";

// Package Imports
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

// Project Imports
import "package:ltc/core/db/db.dart";
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/data_repo.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/settings/setting_keys.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/talent_build/class_build.dart";
import "package:ltc/core/talent_build/class_builds_repo.dart";
import "package:ltc/core/talent_build/share_util.dart";
import "package:ltc/features/calculator/logic/talent_rules.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";

// Relative Project Imports
import "../../helpers/test_db.dart";

const vanilla = 1;
const tbc = 2;
const wotlk = 3;
const forever = 7;
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

  group("Forever Legacy", () {
    Future<void> startForever() async {
      await select(forever, druid);
    }

    List<Talent> legacyTalents(int column) => [
      for (final tree in build().talentTreeTalents.skip(firstLegacyTreeId))
        ...tree.where((t) => t.column == column),
    ];

    int legacySpent() => build().pointsSpentPerTree
        .skip(firstLegacyTreeId)
        .fold(0, (a, b) => a + b);

    test(
      "a Forever build holds the class's trees and the Legacy trees",
      () async {
        await startForever();
        expect(build().talentTrees.map((t) => t.id), [0, 1, 2, 3, 4, 5]);
        expect(build().talentTreeTalents.length, 6);
      },
    );

    test("Legacy points have their own cap, apart from talents", () async {
      await startForever();
      for (final perk in legacyTalents(0)) {
        for (var i = 0; i < perk.ranks.length; i++) {
          notifier().addPoint(perk);
        }
      }
      expect(legacySpent(), maxLegacyPoints);
      expect(build().pointsSpentPerTree.take(3), [0, 0, 0]);
      final unspent = legacyTalents(0)
          .firstWhere((t) => t.currentRank < t.ranks.length);
      expect(notifier().isTalentEnabled(unspent), isFalse);
      final classTalent = build().talentTreeTalents[0].firstWhere(
        (t) => t.row == 0,
      );
      expect(notifier().isTalentEnabled(classTalent), isTrue);
    });

    test("Legacy perks unlock at 5 points per column in their tree", () async {
      await startForever();
      final tree = build().talentTreeTalents[firstLegacyTreeId];
      final gated = tree.firstWhere(
        (t) => t.column == 1 && t.dependencyId == null,
      );
      expect(notifier().isTalentEnabled(gated), isFalse);
      final first = tree.firstWhere((t) => t.column == 0);
      for (var i = 0; i < pointsPerRow; i++) {
        notifier().addPoint(first);
      }
      expect(notifier().isTalentEnabled(gated), isTrue);
    });

    test("a Legacy perk needs one rank of its prerequisite", () async {
      await startForever();
      final tree = build().talentTreeTalents[firstLegacyTreeId];
      final perk = tree.firstWhere(
        (t) => t.column == 1 && t.dependencyId != null,
      );
      final prerequisite = tree.firstWhere((t) => t.id == perk.dependencyId);
      final other = tree.firstWhere(
        (t) => t.column == 0 && t.id != prerequisite.id,
      );
      for (var i = 0; i < pointsPerRow; i++) {
        notifier().addPoint(other);
      }
      expect(notifier().isTalentEnabled(perk), isFalse);
      notifier().addPoint(prerequisite);
      expect(notifier().isTalentEnabled(perk), isTrue);
      notifier().addPoint(perk);
      expect(
        notifier().canRemovePoint(talent: prerequisite),
        isFalse,
        reason: "Not the latest point, and its dependant needs its only rank",
      );
    });

    test("Legacy perks don't hold back undoing talents", () async {
      await startForever();
      final classTalent = build().talentTreeTalents[0].firstWhere(
        (t) => t.row == 0,
      );
      final perk = legacyTalents(0).first;
      notifier().addPoint(classTalent);
      notifier().addPoint(perk);
      expect(notifier().canRemovePoint(talent: classTalent), isTrue);
      expect(notifier().canRemovePoint(talent: perk), isTrue);
    });
  });

  group("share codes", () {
    test("codes round trip for every expansion and class", () async {
      final db = await Db.getDataDbInstance();
      final pairs = await db.rawQuery(
        "SELECT DISTINCT t.expansion e, x.code exp, c.id c, c.code code "
        "FROM talents t JOIN classes c ON c.id = t.classId "
        "JOIN expansions x ON x.id = t.expansion ORDER BY 1, 3",
      );
      expect(pairs.length, 9 + 9 + 10 + 9 + 9 + 10 + 9);
      for (final pair in pairs) {
        final expansion = pair["exp"] as String;
        final classCode = (pair["code"] as String).toLowerCase();
        final counts = await db.rawQuery(
          "SELECT COUNT(*) n FROM talents WHERE expansion = ? "
          "AND classId IN (?, $legacyClassId) "
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

    test("classic codes parse, and unknown expansions don't", () async {
      expect(
        parseShareCode("classic_wotlk-mage-1-2-3")?.expansion,
        "classic_wotlk",
      );
      expect(parseShareCode("retail-mage-1-2-3"), isNull);
    });

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

    test(
      "a code from another version loads, and selects that version",
      () async {
        await select(tbc, mage);
        expect(
          await notifier().importFromShareCode("vanilla-druid-5-0-0"),
          isTrue,
        );
        await container.read(buildStateProvider.future);

        final settings = container.read(settingsProvider).value!;
        expect(settings.selectedExpId, vanilla);
        expect(settings.selectedClassId, druid);
        expect(settings.selectedExp.code, "vanilla");
        expect(build().expansionCode, "vanilla");
        expect(build().classId, druid);
        expect(total(), 5);
      },
    );

    test("a code that fails to import leaves the selection alone", () async {
      await select(tbc, mage);
      expect(
        await notifier().importFromShareCode("forever-deathknight-1-2-3"),
        isFalse,
      );

      final settings = container.read(settingsProvider).value!;
      expect(settings.selectedExpId, tbc);
      expect(settings.selectedClassId, mage);
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
      expect(await notifier().importFromShareCode(code), isTrue);
      expect(talent(t.id).currentRank, 2);
    });

    group("with a build order", () {
      /// Spends [points] on the first talents that accept them, skipping around
      /// so the order isn't just tree by tree.
      List<int> spend(int points) {
        final spent = <int>[];
        var tree = 0;
        while (spent.length < points) {
          final next = build().talentTreeTalents[tree % 3]
              .where(
                (t) =>
                    t.currentRank < t.ranks.length &&
                    notifier().isTalentEnabled(t),
              )
              .firstOrNull;
          if (next != null) {
            notifier().addPoint(next);
            spent.add(next.id);
          }
          tree++;
        }
        return spent;
      }

      List<int> sequence() => [
        for (final point in build().buildSequence) point.talentId,
      ];

      test("the order and ranks come back exactly", () async {
        await select(wotlk, 9);
        final spent = spend(40);
        final ranks = {for (final t in talents()) t.id: t.currentRank};
        final code = buildShareCode(build());
        expect(code, startsWith("wotlk-deathknight-o"));

        await select(tbc, mage);
        expect(await notifier().importFromShareCode(code), isTrue);

        expect(build().expansionCode, "wotlk");
        expect(sequence(), spent);
        final settings = container.read(settingsProvider).value!;
        expect(settings.selectedExpId, wotlk);
        expect(settings.selectedClassId, 9);
        expect({for (final t in talents()) t.id: t.currentRank}, ranks);
        expect(buildShareCode(build()), code);
      });

      test("Legacy points are part of the order", () async {
        await select(forever, druid);
        final perk = build().talentTreeTalents[firstLegacyTreeId].firstWhere(
          (t) => t.column == 0,
        );
        spend(3);
        notifier().addPoint(perk);
        spend(2);
        final spent = sequence();
        final code = buildShareCode(build());

        await select(vanilla, mage);
        expect(await notifier().importFromShareCode(code), isTrue);

        expect(sequence(), spent);
        expect(talent(perk.id).currentRank, 1);
        expect(build().pointsSpentPerTree[firstLegacyTreeId], 1);
      });

      test("an imported order can be undone point by point", () async {
        await select(vanilla, mage);
        final spent = spend(6);
        await notifier().importFromShareCode(buildShareCode(build()));

        expect(notifier().canRemovePoint(), isTrue);
        notifier().removeLastPoint();
        expect(sequence(), spent.sublist(0, 5));
        expect(total(), 5);
      });

      test("a talent-by-talent build is shorter than its digits", () async {
        await select(wotlk, 9);
        final digits = buildShareCode(build()).length;
        while (total() < 71) {
          final next = talents().firstWhere(
            (t) =>
                t.currentRank < t.ranks.length && notifier().isTalentEnabled(t),
          );
          while (next.currentRank < next.ranks.length && total() < 71) {
            if (!notifier().isTalentEnabled(next)) break;
            notifier().addPoint(next);
          }
        }
        final code = buildShareCode(build());
        // ignore: avoid_print
        print("LEN ordered=${code.length} digits=$digits");
        expect(code.length, lessThan(digits));
      });

      test("case changes are fine, but damage is caught", () async {
        await select(vanilla, mage);
        spend(10);
        final code = buildShareCode(build());

        expect(parseShareCode(code.toUpperCase())?.order, isNotNull);
        expect(parseShareCode(code.substring(0, code.length - 2)), isNull);
        expect(parseShareCode(code.substring(0, code.length - 1)), isNull);

        final last = code.length - 3;
        final typo = code[last] == "0" ? "1" : "0";
        expect(parseShareCode(code.replaceRange(last, last + 1, typo)), isNull);
      });

      test("an order that breaks the rules doesn't import", () async {
        await select(vanilla, mage);
        final tree = build().talentTreeTalents[0];
        final locked = tree.firstWhere((t) => t.row == 3);
        // A real sequence for a talent that needs points first, built by hand.
        await notifier().importFromShareCode(
          "vanilla-mage-${"0" * tree.length}-0-0",
        );
        final ordered = talentsInShareOrder(build().talentTreeTalents);
        final index = ordered.indexWhere((t) => t.id == locked.id);
        const base32 = "0123456789abcdefghijklmnopqrstuv";
        final value = index << 3;
        final pair = "${base32[value >> 5]}${base32[value & 31]}";
        final checksums = [
          for (final a in base32.split(""))
            for (final b in base32.split("")) "$a$b",
        ];
        final code = checksums
            .map((c) => "vanilla-mage-o$pair$c")
            .firstWhere((c) => parseShareCode(c) != null);

        expect(await notifier().importFromShareCode(code), isFalse);
      });

      test("builds with an incomplete order fall back to ranks", () async {
        await notifier().importFromShareCode("vanilla-mage-05-0-0");
        expect(buildShareCode(build()), startsWith("vanilla-mage-0"));

        notifier().addPoint(firstInTree(0));
        expect(buildShareCode(build()), isNot(contains("-o")));
      });

      test("every class fits in the encoding's 7 bits per talent", () async {
        final db = await Db.getDataDbInstance();
        final rows = await db.rawQuery(
          "SELECT expansion, classId, COUNT(*) n FROM talents "
          "WHERE classId <> $legacyClassId GROUP BY 1, 2",
        );
        final legacy = await db.rawQuery(
          "SELECT COUNT(*) n FROM talents WHERE classId = $legacyClassId",
        );
        for (final row in rows) {
          final extra = row["expansion"] == forever
              ? legacy.first["n"] as int
              : 0;
          expect((row["n"] as int) + extra, lessThanOrEqualTo(128));
        }
      });

      test("saved builds share with their order", () async {
        await select(vanilla, mage);
        spend(4);
        final id = await notifier().saveBuild("ordered");
        final saved = await ClassBuildsRepo().listBuilds(
          includeBuildPoints: true,
        );
        expect(
          buildShareCode(saved.firstWhere((b) => b.id == id)),
          buildShareCode(build()),
        );
      });
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

  group("glyphs", () {
    const classicWotlk = 6;

    Future<List<Glyph>> catalog([int expansion = wotlk, int cls = mage]) =>
        DataRepo().getGlyphs(expansionId: expansion, classId: cls);

    Iterable<Glyph> ofType(List<Glyph> glyphs, GlyphType type) =>
        glyphs.where((g) => g.type == type);

    test("fill up to three slots of each type, once each", () async {
      await select(wotlk, mage);
      final glyphs = await catalog();
      final majors = ofType(glyphs, GlyphType.major).toList();
      final minors = ofType(glyphs, GlyphType.minor).toList();

      for (final glyph in majors.take(4)) {
        notifier().chooseGlyph(glyph, glyphs);
      }
      notifier().chooseGlyph(majors.first, glyphs);
      notifier().chooseGlyph(minors.first, glyphs);

      expect(build().glyphIds, [
        ...majors.take(3).map((g) => g.id),
        minors.first.id,
      ]);
    });

    test("can be replaced in place and removed", () async {
      await select(wotlk, mage);
      final glyphs = await catalog();
      final majors = ofType(glyphs, GlyphType.major).toList();

      notifier().chooseGlyph(majors[0], glyphs);
      notifier().chooseGlyph(majors[1], glyphs);
      notifier().chooseGlyph(majors[2], glyphs, replacing: majors[0].id);
      expect(build().glyphIds, [majors[2].id, majors[1].id]);

      notifier().chooseGlyph(majors[1], glyphs, replacing: majors[2].id);
      expect(build().glyphIds, [majors[2].id, majors[1].id]);

      notifier().removeGlyph(majors[2].id);
      expect(build().glyphIds, [majors[1].id]);
    });

    test("leave the spent talents alone and are cleared by a reset", () async {
      await select(wotlk, mage);
      final glyphs = await catalog();
      final first = firstInTree(0);
      notifier().addPoint(first);
      notifier().chooseGlyph(glyphs.first, glyphs);

      expect(total(), 1);
      expect(talent(first.id).supports, first.supports);

      await notifier().resetBuild();
      expect(build().glyphIds, isEmpty);
    });

    test("survive saving and loading", () async {
      await select(classicWotlk, mage);
      final glyphs = await catalog(classicWotlk);
      notifier().chooseGlyph(glyphs.first, glyphs);
      notifier().chooseGlyph(glyphs.last, glyphs);

      final id = await notifier().saveBuild("Glyphs");
      await notifier().startNewBuild();
      expect(build().glyphIds, isEmpty);

      await notifier().loadSavedBuild(id);
      expect(build().glyphIds, [glyphs.first.id, glyphs.last.id]);
    });

    test("travel in ordered and ranks-only share codes", () async {
      await select(wotlk, mage);
      final glyphs = await catalog();
      notifier().chooseGlyph(glyphs.first, glyphs);
      final glyphsOnly = buildShareCode(build());
      notifier().addPoint(firstInTree(0));
      final ordered = buildShareCode(build());
      expect(ordered, contains("-o"));

      for (final code in [glyphsOnly, ordered]) {
        await notifier().startNewBuild();
        expect(
          await notifier().importFromShareCode(code),
          isTrue,
          reason: code,
        );
        expect(build().glyphIds, [glyphs.first.id], reason: code);
        expect(buildShareCode(build()), code);
      }
      expect(total(), 1);
    });

    test("a code without glyphs reads as before", () async {
      await select(wotlk, mage);
      notifier().addPoint(firstInTree(0));
      final code = buildShareCode(build());
      expect(code, isNot(contains("-g")));
      expect(parseShareCode(code)!.glyphIds, isEmpty);
    });

    test("a changed code is refused", () async {
      await select(wotlk, mage);
      final glyphs = await catalog();
      notifier().chooseGlyph(glyphs.first, glyphs);
      final code = buildShareCode(build());
      final last = code[code.length - 1];
      expect(
        parseShareCode(
          "${code.substring(0, code.length - 1)}${last == "0" ? "1" : "0"}",
        ),
        isNull,
      );
    });

    test("that don't belong in the build are refused", () async {
      await select(wotlk, mage);
      final mageGlyphs = await catalog();
      final druidGlyphs = await catalog(wotlk, druid);
      final classicOnly = await catalog(classicWotlk, druid);
      final originalIds = druidGlyphs.map((g) => g.id).toSet();
      final newInClassic = classicOnly.firstWhere(
        (g) => !originalIds.contains(g.id),
      );

      Future<bool> importing(List<int> ids, {int cls = mage}) async {
        await select(wotlk, cls);
        final shared = build().copyWith(
          talentTrees: build().talentTrees,
          talentTreeTalents: build().talentTreeTalents,
          buildSequence: build().buildSequence,
          glyphIds: ids,
        );
        return notifier().importFromShareCode(buildShareCode(shared));
      }

      final majors = ofType(mageGlyphs, GlyphType.major).map((g) => g.id);
      final one = majors.first;
      expect(await importing([one]), isTrue);
      expect(await importing([one, one]), isFalse, reason: "twice");
      expect(await importing(majors.take(4).toList()), isFalse, reason: "4");
      expect(await importing([druidGlyphs.first.id]), isFalse, reason: "class");
      expect(
        await importing([newInClassic.id], cls: druid),
        isFalse,
        reason: "edition",
      );

      await select(tbc, mage);
      final tbcBuild = build().copyWith(
        talentTrees: build().talentTrees,
        talentTreeTalents: build().talentTreeTalents,
        buildSequence: build().buildSequence,
        glyphIds: [one],
      );
      expect(
        await notifier().importFromShareCode(buildShareCode(tbcBuild)),
        isFalse,
        reason: "no glyphs in TBC",
      );
    });

    test("follow the language", () async {
      final en = await catalog();
      final de = await DataRepo().getGlyphs(
        expansionId: wotlk,
        classId: mage,
        languageCode: "de",
      );
      expect(de.map((g) => g.id).toSet(), en.map((g) => g.id).toSet());
      expect(de.first.name, isNot(en.first.name));
    });
  });

  group("review regressions", () {
    setUp(() => select(vanilla, mage));

    test("imported ranks survive saving with points spent on top", () async {
      await notifier().importFromShareCode("vanilla-mage-23000-0-0");
      notifier().addPoint(firstInTree(1));

      final id = await notifier().saveBuild("partial order");
      await notifier().loadSavedBuild(id);

      expect(build().pointsSpentPerTree, [5, 1, 0]);
    });

    test("a settings change keeps the active build", () async {
      notifier().addPoint(firstInTree(0));
      final saved = await notifier().saveBuild("saved A");
      await notifier().loadSavedBuild(saved);
      await notifier().startNewBuild();
      notifier().addPoint(firstInTree(1));

      await set(settingsKeyShowOrderNumbers, "true");
      await container.read(buildStateProvider.future);

      expect(build().id, isNull);
      expect(build().pointsSpentPerTree, [0, 1, 0]);
    });

    test("a settings change keeps an imported build out of later ones", () async {
      await notifier().importFromShareCode("vanilla-mage-05-0-0");
      await notifier().startNewBuild();
      notifier().addPoint(firstInTree(1));

      await set(settingsKeyShowOrderNumbers, "true");
      await container.read(buildStateProvider.future);

      expect(build().pointsSpentPerTree, [0, 1, 0]);
    });

    test("a settings change keeps a loaded build with no points", () async {
      final id = await ClassBuildsRepo().insert(build());
      await notifier().loadSavedBuild(id);

      await set(settingsKeyShowOrderNumbers, "true");
      await container.read(buildStateProvider.future);

      expect(build().id, id);
    });

    test("deleting the active build leaves one that can be saved", () async {
      notifier().addPoint(firstInTree(0));
      final id = await notifier().saveBuild("doomed");

      await notifier().deleteBuild(id);

      expect(build().id, isNull);
      expect(total(), 0);
      notifier().addPoint(firstInTree(0));
      expect(await notifier().saveBuild("next"), isNot(0));
    });

    test("a language change translates the class, not a chosen title", () async {
      notifier().addPoint(firstInTree(0));
      await notifier().saveBuild("My PvP build");

      await notifier().relocalize("de");

      expect(build().title, "My PvP build");
      expect(build().className, "Magier");
    });

    test("a language change translates a generated title", () async {
      notifier().addPoint(firstInTree(0));
      await notifier().saveBuild(build().generatedTitle);

      await notifier().relocalize("de");

      expect(build().title, "Magier (1/0/0)");
    });

    test("a language change leaves an imported build untitled", () async {
      await notifier().importFromShareCode("vanilla-mage-05-0-0");

      await notifier().relocalize("de");

      expect(build().title, isEmpty);
      expect(build().suggestedTitle, "Magier (5/0/0)");
    });

    test("a language change keeps the trees in order", () async {
      await select(forever, mage);

      await notifier().relocalize("de");

      expect(build().talentTrees.map((t) => t.id), [0, 1, 2, 3, 4, 5]);
    });
  });
}
