// Package Imports
import "package:sqflite/sqflite.dart";

// Project Imports
import "package:ltc/core/db/db.dart";
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/data_repo.dart";
import "package:ltc/core/settings/settings_service.dart";
import "package:ltc/core/talent_build/build_point.dart";
import "package:ltc/core/talent_build/build_points_repo.dart";
import "package:ltc/core/talent_build/class_build.dart";

/// Talent names that were corrected after release. Saves from older versions
/// are keyed by name, so they need to keep finding these talents.
const _renamedTalents = {
  "Improved Sayaad": "Improved Succubus",
  "Verbesserte Sayaad": "Verbesserter Sukkubus",
  "Unholy Frenzy": "Hysteria",
  "Unheilige Raserei": "Bösartigkeit",
  "Storm,Earth and Fire": "Storm, Earth and Fire",
  "Sturm,Erde und Feuer": "Sturm, Erde und Feuer",
};

class ClassBuildsRepo {
  static final ClassBuildsRepo _instance = ClassBuildsRepo._internal();
  factory ClassBuildsRepo() => _instance;
  ClassBuildsRepo._internal();

  static Future<Database> get _db async => Db.getUserDbInstance();

  final _buildPointsRepo = BuildPointsRepo();
  final _dataRepo = DataRepo();

  Future<int> insert(ClassBuild build) async {
    final db = await _db;
    return await db.transaction<int>((txn) async {
      final id = await txn.insert(
        ClassBuild.tableName,
        build.toDbMap()..remove('id'),
      );
      // Insert build points referencing new id
      final adjusted = build.buildSequence
          .asMap()
          .entries
          .map(
            (e) => BuildPoint(
              id: null,
              classBuildId: id,
              treeId: e.value.treeId,
              talentId: e.value.talentId,
              order: e.key,
            ),
          )
          .toList();
      await _buildPointsRepo.insertAll(adjusted, txn: txn);
      return id;
    });
  }

  Future<void> update(ClassBuild build) async {
    if (build.id == null) {
      throw ArgumentError('Cannot update build without id');
    }
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        ClassBuild.tableName,
        build.toDbMap()..remove('id'),
        where: 'id=?',
        whereArgs: [build.id],
      );
      await _buildPointsRepo.deleteForClassBuild(build.id!, txn: txn);
      final adjusted = build.buildSequence
          .asMap()
          .entries
          .map(
            (e) => BuildPoint(
              id: null,
              classBuildId: build.id!,
              treeId: e.value.treeId,
              talentId: e.value.talentId,
              order: e.key,
            ),
          )
          .toList();
      await _buildPointsRepo.insertAll(adjusted, txn: txn);
    });
  }

  Future<ClassBuild?> fetch(int id, {bool includeBuildPoints = true}) async {
    if (id <= 0) return null;
    final db = await _db;
    final rows = await db.query(
      ClassBuild.tableName,
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final settings = SettingsService.getSettings();

    final row = rows.first;

    final expansionId = row['expansion_id'] as int;
    final classId = row['class_id'] as int;

    // Load full trees & talents (fresh state).
    final talentTrees = await _dataRepo.getTalentTrees(
      expansionId: expansionId,
      classId: classId,
      languageCode: settings.locale.languageCode,
    );
    talentTrees.sort((a, b) => a.id.compareTo(b.id));

    final treeTalents = <List<Talent>>[];
    final talentsMap = await _dataRepo.getTalents(
      expansionId: expansionId,
      classId: classId,
      languageCode: settings.locale.languageCode,
    );

    final talentTreeIds = talentsMap.keys.toList()..sort();

    for (var talentTreeId in talentTreeIds) {
      treeTalents.add(talentsMap[talentTreeId]!);
    }

    List<BuildPoint> points = [];
    if (includeBuildPoints) {
      points = await _buildPointsRepo.fetchByClassBuildId(id);
      points.sort((a, b) => a.order.compareTo(b.order));
    }

    final talentIdsByName = await _dataRepo.getTalentIdsByName(
      expansionId: expansionId,
      classId: classId,
    );
    _renamedTalents.forEach((oldName, newName) {
      final id = talentIdsByName[newName];
      if (id != null) talentIdsByName[oldName] = id;
    });

    // The stored class name is in the language it was saved in, and imports
    // from older versions stored a tree name. Always show the real one.
    final classes = await _dataRepo.getClassesByExpansion(
      expansionId,
      languageCode: settings.locale.languageCode,
    );
    final className = classes
        .where((c) => c.id == classId)
        .firstOrNull
        ?.names[settings.locale.languageCode];

    return ClassBuild.fromDbRow(
      {...row, "class_name": className ?? row["class_name"]},
      talentTrees: talentTrees,
      talentTreeTalents: treeTalents,
      buildSequence: points,
      talentIdsByName: talentIdsByName,
    );
  }

  Future<List<ClassBuild>> listBuilds({
    int? expansionId,
    int? classId,
    bool includeBuildPoints = false,
    int? limit, // NEW: max number of builds to fetch (null = no limit)
  }) async {
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    if (expansionId != null) {
      whereClauses.add('expansion_id=?');
      whereArgs.add(expansionId);
    }
    if (classId != null) {
      whereClauses.add('class_id=?');
      whereArgs.add(classId);
    }
    final rows = await db.query(
      ClassBuild.tableName,
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'id DESC',
      limit: limit, // applies only if not null
    );
    if (rows.isEmpty) return [];
    final builds = <ClassBuild>[];
    for (final row in rows) {
      final build = await fetch(
        row['id'] as int,
        includeBuildPoints: includeBuildPoints,
      );
      if (build != null) builds.add(build);
    }
    return builds;
  }

  Future<int> upsert(ClassBuild entity) async {
    if (entity.id == null) {
      final newId = await insert(entity);

      return newId;
    } else {
      await update(entity);

      return entity.id!;
    }
  }

  Future<void> delete(int id) async {
    if (id <= 0) return;
    final db = await _db;
    // build_points rows will be removed via ON DELETE CASCADE
    await db.delete(ClassBuild.tableName, where: 'id=?', whereArgs: [id]);
  }
}
