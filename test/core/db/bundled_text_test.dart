// Dart Imports
import "dart:io";

// Package Imports
import "package:flutter_test/flutter_test.dart";
import "package:sqflite/sqflite.dart";

// Project Imports
import "package:ltc/core/db/db.dart";

// Relative Project Imports
import "../../helpers/test_db.dart";

void main() {
  late Directory dir;
  late Database db;

  Future<List<String>> offenders(String condition) async {
    final rows = await db.rawQuery(
      "SELECT talentId || ':' || rank || ':' || languageCode AS id "
      "FROM rank_descriptions WHERE $condition",
    );
    return [for (final row in rows) row["id"] as String];
  }

  setUpAll(() async {
    dir = await setUpTestDb();
    db = await Db.getDataDbInstance();
  });
  tearDownAll(() => tearDownTestDb(dir));

  test("descriptions contain no scraped markup", () async {
    expect(await offenders("description LIKE '%<%'"), isEmpty);
  });

  test("descriptions contain no carriage returns", () async {
    expect(await offenders("instr(description, char(13)) > 0"), isEmpty);
  });

  test("commas are followed by a space, except in decimals", () async {
    expect(await offenders("description GLOB '*,[A-Za-z]*'"), isEmpty);
  });

  test("descriptions contain no doubled periods", () async {
    expect(await offenders("description LIKE '%..%'"), isEmpty);
  });

  test("descriptions contain no misread or unevaluated values", () async {
    expect(
      await offenders("description GLOB '*[0-9][0-9][0-9][0-9][0-9][0-9]*'"),
      isEmpty,
    );
    expect(await offenders("description LIKE '%[%'"), isEmpty);
    expect(await offenders("description GLOB '*[0-9]%[0-9]*'"), isEmpty);
    expect(
      await offenders(
        "languageCode = 'de' AND description LIKE '%attack power%'",
      ),
      isEmpty,
    );
    expect(await offenders("description LIKE '%ignore 0 of%'"), isEmpty);
    expect(await offenders("description LIKE '%until cancelled an%'"), isEmpty);
  });

  test("descriptions contain no unrendered client tokens", () async {
    expect(await offenders("description LIKE '%\$%'"), isEmpty);
  });
}
