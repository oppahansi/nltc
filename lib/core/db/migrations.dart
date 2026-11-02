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
