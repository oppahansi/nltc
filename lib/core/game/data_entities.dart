// Project Imports
import "package:ltc/core/game/edition.dart";

class Expansion {
  final int id;
  final String code;
  final Edition edition;

  /// `vanilla`, `tbc` or `wotlk`. Null for an edition without expansions.
  final String? era;
  final Map<String, String> names;

  Expansion({
    required this.id,
    required this.code,
    required this.edition,
    required this.era,
    required this.names,
  });
}

class Class {
  final int id;
  final String color;
  final String code;
  final String icon;
  final Map<String, String> names;

  Class({
    required this.id,
    required this.color,
    required this.code,
    required this.icon,
    required this.names,
  });
}

class TalentTree {
  final int classId;
  final int id;
  final String icon;
  final String background;
  final Map<String, String> names;

  TalentTree({
    required this.classId,
    required this.id,
    required this.icon,
    required this.background,
    required this.names,
  });

  TalentTree copyWith({
    int? classId,
    int? id,
    String? icon,
    String? background,
    Map<String, String>? names,
    bool cloneCollections = true,
  }) {
    return TalentTree(
      classId: classId ?? this.classId,
      id: id ?? this.id,
      icon: icon ?? this.icon,
      background: background ?? this.background,
      names:
          names ??
          (cloneCollections
              ? Map<String, String>.from(this.names)
              : this.names),
    );
  }
}

class Talent {
  final int classId;
  final int talentTreeId;
  final int id;
  final int row;
  final int column;
  final String icon;
  final int? dependencyId;
  final int expansion;
  final Map<String, String> names;
  final List<Rank> ranks;

  int currentRank = 0;
  List<Talent>? supports;

  Talent({
    required this.classId,
    required this.talentTreeId,
    required this.id,
    required this.row,
    required this.column,
    required this.icon,
    required this.dependencyId,
    required this.expansion,
    required this.names,
    required this.ranks,
  });

  Talent copyWith({
    int? classId,
    int? talentTreeId,
    int? id,
    int? row,
    int? column,
    String? icon,
    int? dependencyId,
    int? expansion,
    Map<String, String>? names,
    List<Rank>? ranks,
    int? currentRank,
    List<Talent>? supports,
    bool cloneCollections = true,
  }) {
    final copied = Talent(
      classId: classId ?? this.classId,
      talentTreeId: talentTreeId ?? this.talentTreeId,
      id: id ?? this.id,
      row: row ?? this.row,
      column: column ?? this.column,
      icon: icon ?? this.icon,
      dependencyId: dependencyId ?? this.dependencyId,
      expansion: expansion ?? this.expansion,
      names:
          names ??
          (cloneCollections
              ? Map<String, String>.from(this.names)
              : this.names),
      ranks:
          ranks ??
          (cloneCollections ? List<Rank>.from(this.ranks) : this.ranks),
    );
    copied.currentRank = currentRank ?? this.currentRank;
    copied.supports =
        supports ??
        (this.supports == null
            ? null
            : (cloneCollections
                  ? List<Talent>.from(this.supports!)
                  : this.supports));
    return copied;
  }
}

class Rank {
  final int talentId;
  final int rank;
  final Map<String, String> descriptions;

  Rank({
    required this.talentId,
    required this.rank,
    required this.descriptions,
  });
}

enum GlyphType { major, minor }

class Glyph {
  final int id;
  final int classId;
  final GlyphType type;
  final String icon;
  final String name;
  final String description;

  const Glyph({
    required this.id,
    required this.classId,
    required this.type,
    required this.icon,
    required this.name,
    required this.description,
  });
}
