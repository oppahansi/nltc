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
import "package:ltc/core/db/migrations.dart";
import "package:ltc/core/utils/constants.dart";

class Db {
  static const int dbVersion = 1;

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

  static Future<Database> getDataDbInstance() async {
    if (_dataDbInstance != null) {
      return _dataDbInstance!;
    }

    final dir = await getDatabaseDirectory();
    final path = join(dir.path, dataDbName);

    // Migrate from old location if required
    await _migrateIfNeeded(dataDbName);

    if (!await File(path).exists()) {
      ByteData data = await rootBundle.load(dataDbPath);
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await File(path).writeAsBytes(bytes, flush: true);
    }

    _dataDbInstance = await openDatabase(
      path,
      version: dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await DbMigrations.run(db, 0, version);
      },
      onUpgrade: (db, from, to) async {
        await DbMigrations.run(db, from, to);
      },
      onDowngrade: onDatabaseDowngradeDelete,
    );

    return _dataDbInstance!;
  }

  static Future<Database> getUserDbInstance() async {
    if (_userDbInstance != null) {
      return _userDbInstance!;
    }

    final dir = await getDatabaseDirectory();
    final path = join(dir.path, userDbNane);

    // Migrate from old location if required
    await _migrateIfNeeded(userDbNane);

    if (!await File(path).exists()) {
      ByteData data = await rootBundle.load(userDbPath);
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await File(path).writeAsBytes(bytes, flush: true);
    }

    _userDbInstance = await openDatabase(
      path,
      version: dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await DbMigrations.run(db, 0, version);
      },
      onUpgrade: (db, from, to) async {
        await DbMigrations.run(db, from, to);
      },
      onDowngrade: onDatabaseDowngradeDelete,
    );

    return _userDbInstance!;
  }

  static Future<Database> initializeDataDb() async {
    final dir = await getDatabaseDirectory();
    final path = join(dir.path, dataDbName);

    // Migrate from old location if required
    await _migrateIfNeeded(dataDbName);

    if (!await File(path).exists()) {
      ByteData data = await rootBundle.load(dataDbPath);
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await File(path).writeAsBytes(bytes, flush: true);
    }

    return openDatabase(
      path,
      version: dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await DbMigrations.run(db, 0, version);
      },
      onUpgrade: (db, from, to) async {
        await DbMigrations.run(db, from, to);
      },
      onDowngrade: onDatabaseDowngradeDelete,
    );
  }

  static Future<Database> initializeUserDb() async {
    final dir = await getDatabaseDirectory();
    final path = join(dir.path, userDbNane);

    // Migrate from old location if required
    await _migrateIfNeeded(userDbNane);

    if (!await File(path).exists()) {
      ByteData data = await rootBundle.load(userDbPath);
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await File(path).writeAsBytes(bytes, flush: true);
    }

    return openDatabase(
      path,
      version: dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await DbMigrations.run(db, 0, version);
      },
      onUpgrade: (db, from, to) async {
        await DbMigrations.run(db, from, to);
      },
      onDowngrade: onDatabaseDowngradeDelete,
    );
  }

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
    return join(dir.path, userDbNane);
  }

  /// Create a timestamped backup of the DB inside the app's documents/backups.
  /// Returns the created File.
  static Future<File> backupToAppFolder() async {
    await close();
    final srcPath = await getDbPath();
    final docs = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(join(docs.path, "backups"));
    await backupsDir.create(recursive: true);

    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final name =
        "${appName}_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.db";
    final dest = File(join(backupsDir.path, name));
    return await File(srcPath).copy(dest.path);
  }

  /// Restore the DB from a file (overwrites current DB). Closes DB beforehand.
  static Future<void> restoreFromFile(File source) async {
    await close();
    final destPath = await getDbPath();
    final bytes = await source.readAsBytes();
    await File(destPath).writeAsBytes(bytes, flush: true);
  }
}
