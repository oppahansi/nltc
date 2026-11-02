// Dart Imports
import "dart:io";

// Flutter Imports
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

// Package Imports
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";
import "package:sqflite/sqflite.dart";

// Project Imports
import "package:ltc/core/db/db_constants.dart";
import "package:ltc/core/db/migrations.dart";

class Db {
  static const _sqliteMagic = "SQLite format 3";
  static const _sqliteHeaderSize = 100;
  static const _sqliteUserVersionOffset = 60;

  static Database? _dataDbInstance;
  static Database? _userDbInstance;

  /// When set, DB files live here and the legacy location check is skipped.
  @visibleForTesting
  static Directory? testDirectoryOverride;

  // Resolve a platform-appropriate directory for DB files.
  static Future<Directory> getDatabaseDirectory() async {
    if (testDirectoryOverride != null) {
      return testDirectoryOverride!;
    }
    if (Platform.isAndroid) {
      final dbPath = await getDatabasesPath(); // sqflite helper
      return Directory(dbPath);
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return await getLibraryDirectory();
    }
    // Fallback
    return await getApplicationDocumentsDirectory();
  }

  // Migrate a DB file from the old documents dir to the new platform dir if needed.
  static Future<void> _migrateIfNeeded(String fileName) async {
    if (testDirectoryOverride != null) return;

    final oldDocs = await getApplicationDocumentsDirectory();
    final oldPath = join(oldDocs.path, fileName);

    final newDir = await getDatabaseDirectory();
    final newPath = join(newDir.path, fileName);

    final oldFile = File(oldPath);
    final newFile = File(newPath);

    if (await oldFile.exists() && !await newFile.exists()) {
      // Ensure no DB handles are open
      await _closeAllInstances();

      await newDir.create(recursive: true);
      // Try rename (fast); if fails, copy+delete.
      try {
        await oldFile.rename(newPath);
      } catch (_) {
        final bytes = await oldFile.readAsBytes();
        await newFile.writeAsBytes(bytes, flush: true);
        await oldFile.delete();
      }
    }
  }

  static Future<void> _closeAllInstances() async {
    if (_dataDbInstance != null) {
      try {
        await _dataDbInstance!.close();
      } catch (_) {}
      _dataDbInstance = null;
    }
    if (_userDbInstance != null) {
      try {
        await _userDbInstance!.close();
      } catch (_) {}
      _userDbInstance = null;
    }
  }

  /// The version stamped in a database file's header, or null if there is no
  /// readable database at [path]. Reads the file directly, because opening a
  /// database that's about to be replaced could leave files behind.
  static Future<int?> _fileVersion(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      final header = await handle.read(_sqliteHeaderSize);
      if (header.length < _sqliteHeaderSize) return null;
      if (String.fromCharCodes(header, 0, _sqliteMagic.length) !=
          _sqliteMagic) {
        return null;
      }
      return ByteData.sublistView(header).getInt32(_sqliteUserVersionOffset);
    } on FileSystemException {
      return null;
    } finally {
      await handle?.close();
    }
  }

  /// Copies a bundled database to [path]. The swap is atomic, so a crash leaves
  /// either the old file or the new one, never part of one.
  static Future<void> _installBundled(String assetPath, String path) async {
    final data = await rootBundle.load(assetPath);
    await File(path).parent.create(recursive: true);

    final temp = File("$path.tmp");
    await temp.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    // A leftover journal would be replayed against the new file.
    for (final suffix in ["-journal", "-wal", "-shm"]) {
      final sidecar = File("$path$suffix");
      if (await sidecar.exists()) await sidecar.delete();
    }
    await temp.rename(path);
  }

  /// The game data is read-only and holds nothing of the user's, so any other
  /// version is replaced outright, also when an older app version comes back.
  static Future<Database> getDataDbInstance() async {
    if (_dataDbInstance != null) {
      return _dataDbInstance!;
    }

    final dir = await getDatabaseDirectory();
    final path = join(dir.path, dataDbName);

    // Migrate from old location if required
    await _migrateIfNeeded(dataDbName);

    if (await _fileVersion(path) != dataDbVersion) {
      await _installBundled(dataDbPath, path);
    }

    _dataDbInstance = await openDatabase(path, onConfigure: _configure);
    return _dataDbInstance!;
  }

  /// The user's builds are never replaced: an older file is migrated, and a
  /// newer one, from a downgrade or a restored backup, is opened as it is.
  static Future<Database> getUserDbInstance() async {
    if (_userDbInstance != null) {
      return _userDbInstance!;
    }

    final dir = await getDatabaseDirectory();
    final path = join(dir.path, userDbName);

    // Migrate from old location if required
    await _migrateIfNeeded(userDbName);

    if (!await File(path).exists()) {
      await _installBundled(userDbPath, path);
    }

    final version = await _fileVersion(path);
    if (version != null && version > userDbVersion) {
      _userDbInstance = await openDatabase(path, onConfigure: _configure);
      return _userDbInstance!;
    }

    _userDbInstance = await openDatabase(
      path,
      version: userDbVersion,
      onConfigure: _configure,
      onCreate: (db, version) => DbMigrations.run(db, 0, version),
      onUpgrade: DbMigrations.run,
    );
    return _userDbInstance!;
  }

  static Future<void> _configure(Database db) =>
      db.execute("PRAGMA foreign_keys = ON");

  /// Close the open database so the file can be safely copied or replaced.
  static Future<void> close() async {
    if (_userDbInstance != null) {
      await _userDbInstance!.close();
      _userDbInstance = null;
    }
    if (_dataDbInstance != null) {
      await _dataDbInstance!.close();
      _dataDbInstance = null;
    }
  }

  /// Absolute path to the active database file in the app documents directory.
  static Future<String> getDbPath() async {
    final dir = await getDatabaseDirectory();
    return join(dir.path, userDbName);
  }
}
