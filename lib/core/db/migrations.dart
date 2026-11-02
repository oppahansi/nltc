// Package Imports
import "package:sqflite/sqflite.dart";

typedef Migration = Future<void> Function(Database db);

/// Schema changes for the user DB, whose builds must survive every update. The
/// data DB doesn't use these, since it's replaced as a whole.
class DbMigrations {
  // Key = target version. Each step upgrades from (version-1) -> version.
  static final Map<int, Migration> upgraders = <int, Migration>{
    // 1: baseline, which every shipped version has had. No changes.
    1: (db) async {},
    // 2: glyphs, kept with the build.
    2: (db) async {
      // An unversioned file can't say whether it has the column already, and a
      // failed step would keep the user out of their builds.
      final columns = await db.rawQuery("PRAGMA table_info(class_builds)");
      if (columns.any((column) => column["name"] == "glyphs")) return;
      await db.execute(
        "ALTER TABLE class_builds ADD COLUMN glyphs TEXT NOT NULL DEFAULT '[]'",
      );
    },
  };

  static Future<void> run(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      final step = upgraders[v];
      if (step != null) {
        await step(db);
      }
    }
  }
}
