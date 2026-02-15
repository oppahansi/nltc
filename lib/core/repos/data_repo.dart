// Project Imports
import "package:ltc/core/db/db.dart";
import "package:ltc/core/models/data_entities.dart";
import "package:ltc/core/utils/constants.dart";

class DataRepo {
  static final DataRepo _instance = DataRepo._internal();
  factory DataRepo() => _instance;
  DataRepo._internal();

  /// Fetches all expansions with their localized names.
  Future<List<Expansion>> getExpansions({String? languageCode}) async {
    final langCode = languageCode ?? settingsValueLocaleDefault;
    final db = await Db.getDataDbInstance();
    final result = await db.rawQuery(
      '''
      SELECT e.id, e.code, en.name
      FROM expansions e
      JOIN expansion_names en ON e.id = en.expansionId
      WHERE en.languageCode = ?
    ''',
      [langCode],
    );

    return result
        .map(
          (row) => Expansion(
            id: row['id'] as int,
            code: row['code'] as String,
            names: {langCode: row['name'] as String},
          ),
        )
        .toList();
  }

  /// Fetches classes available in a specific expansion.
  Future<List<Class>> getClassesByExpansion(
    int expansionId, {
    String? languageCode,
  }) async {
    final langCode = languageCode ?? settingsValueLocaleDefault;
    final db = await Db.getDataDbInstance();
    final result = await db.rawQuery(
      '''
      SELECT DISTINCT c.id, c.color, c.code, c.icon, cn.name
      FROM classes c
      JOIN class_names cn ON c.id = cn.classId
      JOIN talents t ON t.classId = c.id
      WHERE t.expansion = ? AND cn.languageCode = ?
    ''',
      [expansionId, langCode],
    );

    return result
        .map(
          (row) => Class(
            id: row['id'] as int,
            color: row['color'] as String,
            code: row['code'] as String,
            icon: row['icon'] as String,
            names: {langCode: row['name'] as String},
          ),
        )
        .toList();
  }

  /// Fetches talent trees (specs) for a given expansion and class.
  Future<List<TalentTree>> getTalentTrees({
    int expansionId = 1,
    int classId = 1,
    String? languageCode,
  }) async {
    final langCode = languageCode ?? settingsValueLocaleDefault;
    final db = await Db.getDataDbInstance();
    final result = await db.rawQuery(
      '''
      SELECT DISTINCT s.classId, s.id, s.icon, s.background, sn.name
      FROM talent_trees s
      JOIN talent_tree_names sn ON s.classId = sn.classId AND s.id = sn.talentTreeId
      JOIN talents t ON t.classId = s.classId AND t.talentTreeId = s.id
      WHERE t.expansion = ? AND s.classId = ? AND sn.languageCode = ?
    ''',
      [expansionId, classId, langCode],
    );

    return result
        .map(
          (row) => TalentTree(
            classId: row['classId'] as int,
            id: row['id'] as int,
            icon: row['icon'] as String,
            background: row['background'] as String,
            names: {langCode: row['name'] as String},
          ),
        )
        .toList();
  }

  Future<Map<int, List<Talent>>> getTalents({
    int expansionId = 1,
    int classId = 0,
    String? languageCode,
  }) async {
    final langCode = languageCode ?? settingsValueLocaleDefault;

    final db = await Db.getDataDbInstance();
    // Fetch talents
    final talentResult = await db.rawQuery(
      '''
      SELECT t.classId, t.talentTreeId, t.id, t.row, t.column, t.icon, t.dependencyId, t.expansion, tn.name
      FROM talents t
      JOIN talent_names tn ON t.id = tn.talentId
      WHERE t.expansion = ? AND t.classId = ? AND t.talentTreeId IN  (0, 1, 2) AND tn.languageCode = ?
    ''',
      [expansionId, classId, langCode],
    );

    final talents = <Talent>[];
    for (var row in talentResult) {
      // Fetch ranks for this talent
      final ranksResult = await db.rawQuery(
        '''
        SELECT r.talentId, r.rank, rd.description
        FROM ranks r
        LEFT JOIN rank_descriptions rd ON r.talentId = rd.talentId AND r.rank = rd.rank AND rd.languageCode = ?
        WHERE r.talentId = ?
      ''',
        [langCode, row['id']],
      );

      final ranks = ranksResult
          .map(
            (r) => Rank(
              talentId: r['talentId'] as int,
              rank: r['rank'] as int,
              descriptions: r['description'] != null
                  ? {langCode: r['description'] as String}
                  : {},
            ),
          )
          .toList();

      talents.add(
        Talent(
          classId: row['classId'] as int,
          talentTreeId: row['talentTreeId'] as int,
          id: row['id'] as int,
          row: row['row'] as int,
          column: row['column'] as int,
          icon: row['icon'] as String,
          dependencyId: row['dependencyId'] != null
              ? row['dependencyId'] as int
              : null,
          expansion: row['expansion'] as int,
          names: {langCode: row['name'] as String},
          ranks: ranks,
        ),
      );

      // Fetch and assign supports
      for (var talent in talents) {
        talent.supports = talents
            .where((t) => t.dependencyId == talent.id)
            .toList();
      }
    }

    final talentsMap = <int, List<Talent>>{};
    for (var talent in talents) {
      talentsMap.putIfAbsent(talent.talentTreeId, () => []).add(talent);
    }

    return talentsMap;
  }

  /// Fetches dependencies for a specific talent.
  Future<List<Dependency>> getDependenciesForTalent(int talentId) async {
    final db = await Db.getDataDbInstance();
    final result = await db.rawQuery(
      '''
      SELECT talentId, dependencyId
      FROM dependencies
      WHERE talentId = ?
    ''',
      [talentId],
    );

    return result
        .map(
          (row) => Dependency(
            talentId: row['talentId'] as int,
            dependencyId: row['dependencyId'] as int,
          ),
        )
        .toList();
  }
}
