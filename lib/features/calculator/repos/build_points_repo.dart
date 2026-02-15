// Package Imports
import "package:sqflite/sqflite.dart";

// Project Imports
import "package:ltc/core/db/db.dart";
import "package:ltc/features/calculator/models/build_point.dart";

class BuildPointsRepo {
  static final BuildPointsRepo _instance = BuildPointsRepo._internal();
  factory BuildPointsRepo() => _instance;
  BuildPointsRepo._internal();

  static Future<Database> get _db async => Db.getUserDbInstance();

  Future<List<BuildPoint>> fetchByClassBuildId(
    int classBuildId, {
    Database? txn,
  }) async {
    final db = txn ?? await _db;
    final rows = await db.query(
      BuildPoint.tableName,
      where: 'class_build_id=?',
      whereArgs: [classBuildId],
      orderBy: '"order"',
    );
    return rows.map(BuildPoint.fromDbRow).toList();
  }

  Future<int> insert(BuildPoint bp, {Database? txn}) async {
    final db = txn ?? await _db;
    return db.insert(BuildPoint.tableName, bp.toDbMap());
  }

  Future<void> insertAll(
    List<BuildPoint> points, {
    DatabaseExecutor? txn,
  }) async {
    if (points.isEmpty) return;
    final db = txn ?? await _db;
    final batch = db.batch();
    for (final p in points) {
      batch.insert(BuildPoint.tableName, p.toDbMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteForClassBuild(
    int classBuildId, {
    DatabaseExecutor? txn,
  }) async {
    final db = txn ?? await _db;
    await db.delete(
      BuildPoint.tableName,
      where: 'class_build_id=?',
      whereArgs: [classBuildId],
    );
  }
}
