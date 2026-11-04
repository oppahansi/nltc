// Dart Imports
import "dart:io";

// Flutter Imports
import "package:flutter/services.dart";

// Project Imports
import "package:ltc/core/db/db.dart";

/// Dart side helper for native export/import pickers via MethodChannel.
/// No third-party packages; platform code uses Android SAF and iOS UIDocumentPicker.
class NativeBackup {
  static const MethodChannel _ch = MethodChannel("app.backup");

  /// Opens system save dialog and writes the DB to the chosen location.
  /// Returns true if the operation succeeded.
  static Future<bool> exportWithPicker() async {
    final dbPath = await Db.getDbPath();
    await Db.close();
    final ok = await _ch.invokeMethod<bool>("exportDb", {
      "dbPath": dbPath,
      "suggestedName": "ltc_backup.db",
    });
    return ok == true;
  }

  /// Opens system open dialog and replaces the DB with the chosen file. The file
  /// is copied aside and checked first, so a wrong or damaged one can't touch the
  /// user's builds. Returns true if the operation succeeded, and throws a
  /// [FormatException] if the file isn't a backup.
  static Future<bool> importWithPicker() async {
    final restorePath = "${await Db.getDbPath()}.restore";
    await Db.close();
    try {
      final ok = await _ch.invokeMethod<bool>("importDb", {
        "dbPath": restorePath,
      });
      if (ok != true) return false;
      if (!await Db.isUserDb(restorePath)) {
        throw const FormatException("Not a backup of this app's builds");
      }
      await Db.replaceUserDb(restorePath);
      return true;
    } finally {
      final leftover = File(restorePath);
      if (await leftover.exists()) await leftover.delete();
    }
  }
}
