// Dart Imports
import "dart:io";

// Package Imports
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart";
import "package:sqflite/sqflite.dart";

// Project Imports
import "package:ltc/core/db/db.dart";
import "package:ltc/core/db/db_constants.dart";

// Relative Project Imports
import "../../helpers/test_db.dart";

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

  test("copies the bundled user DB on first open, with no builds", () async {
    final db = await Db.getUserDbInstance();

    final count = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM class_builds"),
    );
    expect(count, 0);
  });
}
