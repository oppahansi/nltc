// Project Imports
import "package:ltc/core/db/db.dart";
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/edition.dart";
import "package:ltc/core/game/game_catalog.dart";

class DataRepo {
  static final DataRepo _instance = DataRepo._internal();
  factory DataRepo() => _instance;
  DataRepo._internal();

  /// Fetches expansions that have talent data, with their localized names.
  Future<List<Expansion>> getExpansions({String? languageCode}) async {
    final langCode = languageCode ?? defaultLanguageCode;
    final db = await Db.getDataDbInstance();
    final result = await db.rawQuery(
      '''
      SELECT e.id, e.code, e.edition, e.era, en.name
      FROM expansions e
      JOIN expansion_names en ON e.id = en.expansionId
      WHERE en.languageCode = ?
        AND EXISTS (SELECT 1 FROM talents t WHERE t.expansion = e.id)
    ''',
      [langCode],
    );

    return result
        .map(
          (row) => Expansion(
            id: row['id'] as int,
            code: row['code'] as String,
            edition: Edition.fromCode(row['edition'] as String),
            era: row['era'] as String?,
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
    final langCode = languageCode ?? defaultLanguageCode;
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

  /// Fetches talent trees (specs) for a given expansion and class, by id. Tabs and
  /// `pointsSpentPerTree` rely on that order.
  Future<List<TalentTree>> getTalentTrees({
    int expansionId = 1,
    int classId = 1,
    String? languageCode,
  }) async {
    final langCode = languageCode ?? defaultLanguageCode;
    final db = await Db.getDataDbInstance();
    final result = await db.rawQuery(
      '''
      SELECT DISTINCT s.classId, s.id, COALESCE(o.icon, s.icon) AS icon, s.background, sn.name
      FROM talent_trees s
      JOIN talent_tree_names sn ON s.classId = sn.classId AND s.id = sn.talentTreeId
      JOIN talents t ON t.classId = s.classId AND t.talentTreeId = s.id
      LEFT JOIN talent_tree_icons o
        ON o.expansionId = t.expansion AND o.classId = s.classId AND o.talentTreeId = s.id
      WHERE t.expansion = ? AND s.classId IN (?, $legacyClassId) AND sn.languageCode = ?
      ORDER BY s.id
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

  /// A class's glyphs by name. Empty for an expansion without glyphs.
  Future<List<Glyph>> getGlyphs({
    required int expansionId,
    required int classId,
    String? languageCode,
  }) async {
    final db = await Db.getDataDbInstance();
    final rows = await db.rawQuery(
      '''
      SELECT g.id, g.classId, g.type, g.icon, gt.name, gt.description
      FROM glyphs g
      JOIN glyph_texts gt ON gt.expansion = g.expansion AND gt.glyphId = g.id
      WHERE g.expansion = ? AND g.classId = ? AND gt.languageCode = ?
      ORDER BY gt.name
    ''',
      [expansionId, classId, languageCode ?? defaultLanguageCode],
    );
    return rows
        .map(
          (row) => Glyph(
            id: row['id'] as int,
            classId: row['classId'] as int,
            type: GlyphType.values.byName(row['type'] as String),
            icon: row['icon'] as String,
            name: row['name'] as String,
            description: row['description'] as String,
          ),
        )
        .toList();
  }

  /// Every name a class's talents have, in any language, mapped to talent id.
  /// If two talents share a name, the lower id wins.
  Future<Map<String, int>> getTalentIdsByName({
    required int expansionId,
    required int classId,
  }) async {
    final db = await Db.getDataDbInstance();
    final rows = await db.rawQuery(
      '''
      SELECT tn.name, MIN(t.id) AS id
      FROM talents t
      JOIN talent_names tn ON t.id = tn.talentId
      WHERE t.expansion = ? AND t.classId = ?
      GROUP BY tn.name
    ''',
      [expansionId, classId],
    );
    return {for (final r in rows) r['name'] as String: r['id'] as int};
  }

  Future<Map<int, List<Talent>>> getTalents({
    int expansionId = 1,
    int classId = 0,
    String? languageCode,
  }) async {
    final langCode = languageCode ?? defaultLanguageCode;

    final db = await Db.getDataDbInstance();
    // Fetch talents
    final talentResult = await db.rawQuery(
      '''
      SELECT t.classId, t.talentTreeId, t.id, t.row, t.column, t.icon, t.dependencyId, t.expansion, tn.name
      FROM talents t
      JOIN talent_names tn ON t.id = tn.talentId
      WHERE t.expansion = ? AND t.classId IN (?, $legacyClassId) AND tn.languageCode = ?
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
}
