// Dart Imports
import "dart:io";
import "dart:typed_data";

// Package Imports
import "package:crypto/crypto.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart";
import "package:sqflite/sqflite.dart";

// Project Imports
import "package:ltc/core/db/db.dart";
import "package:ltc/core/db/db_constants.dart";

// Relative Project Imports
import "../../helpers/test_db.dart";

/// The SQL that [dataDbVersion] stands for. See "data changes come with a
/// version bump".
const dataSqlHash =
    "721e79f337bb965bd37d6459e456ffa0cbe194e807f7e90cf2bdc9fa23194305";

void main() {
  late Directory dir;

  setUp(() async => dir = await setUpTestDb());
  tearDown(() => tearDownTestDb(dir));

  test("copies the bundled data DB on first open", () async {
    final db = await Db.getDataDbInstance();

    expect(File(join(dir.path, dataDbName)).existsSync(), isTrue);
    final count = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM talents"),
    );
    expect(count, greaterThanOrEqualTo(1840));
  });

  group("bundled files", () {
    int stamped(String name) {
      final bytes = File("assets/db/$name").readAsBytesSync();
      return ByteData.sublistView(bytes).getInt32(60);
    }

    test("carry the versions the code expects", () {
      expect(stamped(dataDbName), dataDbVersion);
      expect(stamped(userDbName), userDbVersion);
    });

    test("data changes come with a version bump", () {
      final sql = File("assets/db/$dataDbName.sql").readAsBytesSync();
      expect(
        sha256.convert(sql).toString(),
        dataSqlHash,
        reason:
            "The bundled data changed. Installs only get it through a new "
            "version: bump dataDbVersion and PRAGMA user_version, rebuild the "
            "DB, then update dataSqlHash.",
      );
    });
  });

  group("data DB", () {
    String path() => join(dir.path, dataDbName);

    /// Puts the bundled DB in place as if another version had installed it.
    Future<void> install(int version) async {
      File(join("assets/db", dataDbName)).copySync(path());
      final db = await openDatabase(path());
      await db.execute("DROP TABLE dependencies");
      await db.setVersion(version);
      await db.close();
    }

    Future<bool> wasReplaced() async {
      final db = await Db.getDataDbInstance();
      final tables = await db.rawQuery(
        "SELECT 1 FROM sqlite_master WHERE name = 'dependencies'",
      );
      return tables.isNotEmpty;
    }

    test("an older version is replaced", () async {
      await install(dataDbVersion - 1);
      expect(await wasReplaced(), isTrue);
      expect(await (await Db.getDataDbInstance()).getVersion(), dataDbVersion);
    });

    test("a newer version is replaced", () async {
      await install(dataDbVersion + 1);
      expect(await wasReplaced(), isTrue);
    });

    test("the current version is left alone", () async {
      await install(dataDbVersion);
      expect(await wasReplaced(), isFalse);
    });

    test("an unreadable file is replaced", () async {
      File(path()).writeAsStringSync("not a database");
      expect(await wasReplaced(), isTrue);
    });

    test("no temporary file or stale journal stays behind", () async {
      await install(dataDbVersion - 1);
      File("${path()}-journal").writeAsStringSync("stale");
      await Db.getDataDbInstance();
      expect(File("${path()}.tmp").existsSync(), isFalse);
      expect(File("${path()}-journal").existsSync(), isFalse);
    });
  });

  group("user DB", () {
    String path() => join(dir.path, userDbName);

    /// A file holding one build, as if another app version had saved it.
    Future<void> install(int version) async {
      File(join("assets/db", userDbName)).copySync(path());
      final db = await openDatabase(path());
      await db.insert("class_builds", {
        "title": "Kept",
        "expansion_id": 1,
        "expansion_code": "vanilla",
        "class_id": 0,
        "class_name": "Druid",
        "talent_ranks": "{}",
        "talents_build_sequence": "[]",
      });
      await db.setVersion(version);
      await db.close();
    }

    Future<int> builds() async => Sqflite.firstIntValue(
      await (await Db.getUserDbInstance()).rawQuery(
        "SELECT COUNT(*) FROM class_builds WHERE title = 'Kept'",
      ),
    )!;

    test("the same version keeps its builds", () async {
      await install(userDbVersion);
      expect(await builds(), 1);
    });

    test("a newer version keeps its builds and its version", () async {
      await install(userDbVersion + 1);
      expect(await builds(), 1);
      expect(
        await (await Db.getUserDbInstance()).getVersion(),
        userDbVersion + 1,
      );
    });

    test("an unversioned file keeps its builds", () async {
      await install(0);
      expect(await builds(), 1);
      expect(await (await Db.getUserDbInstance()).getVersion(), userDbVersion);
    });
  });

  group("user DB glyph upgrade", () {
    String path() => join(dir.path, userDbName);

    /// A file as every version before glyphs left it, holding one build.
    Future<void> installBeforeGlyphs() async {
      File(join("assets/db", userDbName)).copySync(path());
      final db = await openDatabase(path());
      await db.execute("ALTER TABLE class_builds DROP COLUMN glyphs");
      await db.insert("class_builds", {
        "title": "Kept",
        "expansion_id": 3,
        "expansion_code": "wotlk",
        "class_id": 2,
        "class_name": "Mage",
        "talent_ranks": "{}",
        "talents_build_sequence": "[]",
      });
      await db.setVersion(1);
      await db.close();
    }

    test("keeps builds and gives them no glyphs", () async {
      await installBeforeGlyphs();
      final db = await Db.getUserDbInstance();
      expect(await db.getVersion(), userDbVersion);
      final rows = await db.query("class_builds");
      expect(rows.single["title"], "Kept");
      expect(rows.single["glyphs"], "[]");
    });

    test("matches the schema of a new install", () async {
      List<String> columns(List<Map<String, Object?>> info) => info
          .map((c) => "${c["name"]} ${c["type"]} ${c["dflt_value"]}")
          .toList();

      await installBeforeGlyphs();
      final upgraded = columns(
        await (await Db.getUserDbInstance()).rawQuery(
          "PRAGMA table_info(class_builds)",
        ),
      );
      final bundled = await openDatabase(
        File(join("assets/db", userDbName)).absolute.path,
        readOnly: true,
      );
      addTearDown(bundled.close);
      expect(
        upgraded,
        columns(await bundled.rawQuery("PRAGMA table_info(class_builds)")),
      );
    });
  });

  test("copies the bundled user DB on first open, with no builds", () async {
    final db = await Db.getUserDbInstance();

    final count = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM class_builds"),
    );
    expect(count, 0);
  });
}
