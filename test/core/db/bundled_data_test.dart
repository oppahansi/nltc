// Dart Imports
import "dart:io";

// Package Imports
import "package:flutter_test/flutter_test.dart";
import "package:sqflite/sqflite.dart";

// Project Imports
import "package:ltc/core/db/db.dart";
import "package:ltc/core/game/game_catalog.dart";

// Relative Project Imports
import "../../helpers/test_db.dart";

void main() {
  late Directory dir;
  late Database db;

  Future<List<String>> strings(String sql) async {
    final rows = await db.rawQuery(sql);
    return [for (final row in rows) row.values.first.toString()];
  }

  setUpAll(() async {
    dir = await setUpTestDb();
    db = await Db.getDataDbInstance();
  });
  tearDownAll(() => tearDownTestDb(dir));

  group("frozen ids", () {
    // Saved builds and share codes refer to these rows, so they must not change.
    test("expansion rows 1-3 keep their ids and codes", () async {
      final rows = await db.rawQuery(
        "SELECT id, code FROM expansions WHERE id <= 3 ORDER BY id",
      );
      expect(rows, [
        {"id": 1, "code": "vanilla"},
        {"id": 2, "code": "tbc"},
        {"id": 3, "code": "wotlk"},
      ]);
    });

    test("talent ids of rows 1-3 keep their blocks", () async {
      final rows = await db.rawQuery(
        "SELECT expansion, MIN(id) lo, MAX(id) hi, COUNT(*) n FROM talents "
        "WHERE expansion <= 3 GROUP BY expansion ORDER BY expansion",
      );
      expect(rows, [
        {"expansion": 1, "lo": 0, "hi": 431, "n": 432},
        {"expansion": 2, "lo": 432, "hi": 1010, "n": 579},
        {"expansion": 3, "lo": 1011, "hi": 1839, "n": 829},
      ]);
    });
  });

  group("Forever rows", () {
    Future<int> count(String where) async => Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM talents WHERE $where"),
    )!;

    test("every class gets the three Legacy trees' 21 perks", () async {
      expect(await count("expansion = 7 AND classId = $legacyClassId"), 21);
      expect(await count("expansion = 7 AND classId <> $legacyClassId"), 464);
      expect(await count("classId = $legacyClassId AND expansion <> 7"), 0);
    });

    test("Legacy perks fit the grid, and placeholders are left out", () async {
      expect(
        await count(
          "classId = $legacyClassId AND "
          '(talentTreeId NOT IN (3, 4, 5) OR row > 3 OR "column" > 2)',
        ),
        0,
      );
      expect(
        await strings("SELECT name FROM talent_names WHERE name = 'Unknown'"),
        isEmpty,
      );
    });

    test("ids are client node ids, clear of the other editions", () async {
      expect(await count("expansion = 7 AND id < 100000"), 0);
    });
  });

  group("Classic rows", () {
    for (final (classic, original, offset) in [
      (4, 1, 10000),
      (5, 2, 20000),
      (6, 3, 30000),
    ]) {
      test(
        "row $classic has the layout of row $original, ids offset",
        () async {
          Future<List<Map<String, Object?>>> layout(
            int expansion,
            int by,
          ) => db.rawQuery(
            'SELECT id - $by AS id, classId, talentTreeId, row, "column", '
            "dependencyId - $by AS dep, "
            "(SELECT COUNT(*) FROM ranks r WHERE r.talentId = t.id) AS ranks "
            "FROM talents t WHERE expansion = $expansion ORDER BY 1",
          );
          final rows = await layout(classic, offset);
          expect(rows, isNotEmpty);
          expect(rows, await layout(original, 0));
        },
      );
    }

    test("tree icon overrides name existing assets", () async {
      for (final icon in await strings("SELECT icon FROM talent_tree_icons")) {
        expect(File("assets/images/icons/$icon.webp").existsSync(), isTrue);
      }
    });
  });

  test(
    "every expansion has a known edition, and an era unless it's Forever",
    () async {
      final rows = await db.rawQuery(
        "SELECT code, edition, era FROM expansions",
      );
      for (final row in rows) {
        expect(["original", "classic", "forever"], contains(row["edition"]));
        expect(row["era"] == null, row["edition"] == "forever", reason: "$row");
      }
    },
  );

  group("translations", () {
    for (final lang in ["en", "de"]) {
      test("every talent has a $lang name", () async {
        expect(
          await strings(
            "SELECT t.id FROM talents t WHERE NOT EXISTS (SELECT 1 FROM talent_names n "
            "WHERE n.talentId = t.id AND n.languageCode = '$lang')",
          ),
          isEmpty,
        );
      });

      test("every rank has a $lang description", () async {
        expect(
          await strings(
            "SELECT r.talentId || ':' || r.rank FROM ranks r WHERE NOT EXISTS (SELECT 1 "
            "FROM rank_descriptions d WHERE d.talentId = r.talentId AND d.rank = r.rank "
            "AND d.languageCode = '$lang')",
          ),
          isEmpty,
        );
      });

      test("every tree has a $lang name", () async {
        expect(
          await strings(
            "SELECT t.classId || ':' || t.id FROM talent_trees t WHERE NOT EXISTS (SELECT 1 "
            "FROM talent_tree_names n WHERE n.classId = t.classId AND n.talentTreeId = t.id "
            "AND n.languageCode = '$lang')",
          ),
          isEmpty,
        );
      });
    }
  });

  group("integrity", () {
    test("every talent has at least one rank", () async {
      expect(
        await strings(
          "SELECT t.id FROM talents t WHERE NOT EXISTS "
          "(SELECT 1 FROM ranks r WHERE r.talentId = t.id)",
        ),
        isEmpty,
      );
    });

    test("every prerequisite is in the same class, tree and expansion", () async {
      expect(
        await strings(
          "SELECT t.id FROM talents t LEFT JOIN talents p ON p.id = t.dependencyId "
          "WHERE t.dependencyId IS NOT NULL AND (p.id IS NULL OR p.classId != t.classId "
          "OR p.talentTreeId != t.talentTreeId OR p.expansion != t.expansion)",
        ),
        isEmpty,
      );
    });
  });

  group("talent names", () {
    test("commas are followed by a space", () async {
      expect(
        await strings(
          "SELECT name FROM talent_names WHERE name GLOB '*,[A-Za-z]*'",
        ),
        isEmpty,
      );
    });

    test("names from later game versions are gone", () async {
      expect(
        await strings(
          "SELECT n.name FROM talent_names n JOIN talents t ON t.id = n.talentId "
          "JOIN expansions e ON e.id = t.expansion "
          "WHERE e.edition = 'original' AND n.name IN ('Improved Sayaad', "
          "'Unholy Frenzy', 'Verbesserte Sayaad', 'Unheilige Raserei')",
        ),
        isEmpty,
      );
    });
  });

  group("assets", () {
    List<String> missing(Iterable<String> paths) => [
      for (final path in paths)
        if (!File(path).existsSync()) path,
    ];

    test("every talent and tree icon exists", () async {
      final icons = await strings(
        "SELECT icon FROM talents UNION SELECT icon FROM talent_trees",
      );
      expect(missing(icons.map((i) => "assets/images/icons/$i.webp")), isEmpty);
    });

    test("every tree background exists", () async {
      final backgrounds = await strings("SELECT background FROM talent_trees");
      expect(
        missing(backgrounds.map((b) => "assets/images/bgs/$b.webp")),
        isEmpty,
      );
    });
  });

  group("glyphs", () {
    test("only WotLK has them, with the counts of its clients", () async {
      final rows = await db.rawQuery(
        "SELECT expansion, COUNT(*) AS n FROM glyphs GROUP BY expansion ORDER BY expansion",
      );
      expect(rows, [
        {"expansion": 3, "n": 345},
        {"expansion": 6, "n": 348},
      ]);
    });

    test("every class can fill every slot", () async {
      final rows = await db.rawQuery(
        "SELECT expansion, classId, type, COUNT(*) AS n FROM glyphs "
        "GROUP BY expansion, classId, type",
      );
      expect(rows, hasLength(2 * classNamesToIds.length * 2));
      for (final row in rows) {
        expect(
          row["n"] as int,
          greaterThanOrEqualTo(glyphSlotsPerType),
          reason: "$row",
        );
      }
    });

    test("every glyph has a name and text in both languages", () async {
      final incomplete = await strings(
        "SELECT g.expansion || '/' || g.id FROM glyphs g WHERE ("
        "SELECT COUNT(*) FROM glyph_texts t WHERE t.expansion = g.expansion "
        "AND t.glyphId = g.id AND t.languageCode IN ('en', 'de') "
        "AND t.name <> '' AND t.description <> '') <> 2",
      );
      expect(incomplete, isEmpty);
    });

    test("no text holds an unrendered client token", () async {
      final raw = await strings(
        "SELECT name || ' ' || description FROM glyph_texts "
        "WHERE name || description LIKE '%\$%' OR name || description LIKE '%[[%'",
      );
      expect(raw, isEmpty);
    });

    test("every icon exists", () async {
      final icons = await strings("SELECT DISTINCT icon FROM glyphs");
      expect(icons, hasLength(20));
      for (final icon in icons) {
        expect(File("assets/images/icons/$icon.webp").existsSync(), isTrue);
      }
    });
  });
}
