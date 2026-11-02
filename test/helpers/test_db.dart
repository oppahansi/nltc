// Dart Imports
import "dart:io";

// Flutter Imports
import "package:flutter_test/flutter_test.dart";

// Package Imports
import "package:sqflite_common_ffi/sqflite_ffi.dart";

// Project Imports
import "package:ltc/core/db/db.dart";

/// Points [Db] at a fresh temporary directory, using FFI SQLite, so a test gets
/// the same first-install copy of the bundled databases as a new user.
///
/// Call from `setUp`, and call [tearDownTestDb] with the result from `tearDown`.
Future<Directory> setUpTestDb() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dir = await Directory.systemTemp.createTemp("ltc_test_");
  Db.testDirectoryOverride = dir;
  return dir;
}

Future<void> tearDownTestDb(Directory dir) async {
  await Db.close();
  Db.testDirectoryOverride = null;
  await dir.delete(recursive: true);
}
