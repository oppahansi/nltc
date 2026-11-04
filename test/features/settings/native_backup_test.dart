// Dart Imports
import "dart:io";

// Flutter Imports
import "package:flutter/services.dart";

// Package Imports
import "package:flutter_test/flutter_test.dart";
import "package:sqflite_common_ffi/sqflite_ffi.dart";

// Project Imports
import "package:ltc/core/db/db.dart";
import "package:ltc/features/settings/services/native_backup.dart";

// Relative Project Imports
import "../../helpers/test_db.dart";

const _channel = MethodChannel("app.backup");

void main() {
  late Directory dir;

  /// Has the native picker deliver [bytes], as a real one copies the picked file
  /// to the path it's given.
  void pick(List<int> bytes) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          File(call.arguments["dbPath"] as String).writeAsBytesSync(bytes);
          return true;
        });
  }

  Future<void> addBuild(String title) async {
    final db = await Db.getUserDbInstance();
    await db.insert("class_builds", {
      "title": title,
      "expansion_id": 1,
      "expansion_code": "vanilla",
      "class_id": 2,
      "class_name": "Mage",
      "talent_ranks": "{}",
      "talents_build_sequence": "[]",
      "glyphs": "[]",
    });
  }

  Future<List<Object?>> titles() async {
    final db = await Db.getUserDbInstance();
    final rows = await db.query("class_builds");
    return rows.map((row) => row["title"]).toList();
  }

  Future<void> expectBuildsKept(List<int> bytes) async {
    pick(bytes);
    await expectLater(
      NativeBackup.importWithPicker(),
      throwsA(isA<FormatException>()),
    );
    expect(await titles(), ["mine"]);
    expect(File("${await Db.getDbPath()}.restore").existsSync(), isFalse);
  }

  setUp(() async {
    dir = await setUpTestDb();
    await addBuild("mine");
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await tearDownTestDb(dir);
  });

  test("a backup replaces the builds", () async {
    await addBuild("backed up");
    await Db.close();
    final backup = File(await Db.getDbPath()).readAsBytesSync();
    final db = await Db.getUserDbInstance();
    await db.delete("class_builds");
    await addBuild("newer");

    pick(backup);

    expect(await NativeBackup.importWithPicker(), isTrue);
    expect(await titles(), ["mine", "backed up"]);
  });

  test("a file that isn't a database keeps the builds", () async {
    await expectBuildsKept("%PDF-1.7 ${"x" * 500}".codeUnits);
  });

  test("an empty file keeps the builds", () async {
    await expectBuildsKept(const []);
  });

  test("a damaged database keeps the builds", () async {
    await Db.close();
    final bytes = File(await Db.getDbPath()).readAsBytesSync();
    await expectBuildsKept(bytes.sublist(0, bytes.length ~/ 2));
  });

  test("another app's database keeps the builds", () async {
    final other = "${dir.path}/other.db";
    final db = await databaseFactory.openDatabase(other);
    await db.execute("CREATE TABLE notes (id INTEGER)");
    await db.close();
    await expectBuildsKept(File(other).readAsBytesSync());
  });
}
