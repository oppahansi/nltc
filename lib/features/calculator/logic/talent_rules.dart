// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/talent_build/class_build.dart";

const pointsPerRow = 5;

/// The points [talent]'s tree needs before it unlocks. Talent trees read top to
/// bottom, gated by row, and Legacy trees left to right, gated by column.
int _pointsRequired(Talent talent) =>
    (isLegacyTree(talent.talentTreeId) ? talent.column : talent.row) *
    pointsPerRow;

/// The rank a prerequisite needs: all of them, except that one is enough in a
/// Legacy tree, going by Wowhead's calculator.
int _ranksRequiredOf(Talent prerequisite) =>
    isLegacyTree(prerequisite.talentTreeId) ? 1 : prerequisite.ranks.length;

/// The points spent on the same side of the build as [treeId]: its class's
/// talents, or its Legacy perks, which have their own cap.
int _pointsSpentAlongside(ClassBuild build, int treeId) {
  var spent = 0;
  for (var i = 0; i < build.pointsSpentPerTree.length; i++) {
    if (isLegacyTree(i) == isLegacyTree(treeId)) {
      spent += build.pointsSpentPerTree[i];
    }
  }
  return spent;
}

/// Whether [talent] can take another point: the build is under its point cap,
/// the tree has enough points for the talent's row, and any prerequisite is full.
bool isTalentEnabled(ClassBuild build, Talent talent) {
  final maxPoints = isLegacyTree(talent.talentTreeId)
      ? maxLegacyPoints
      : maxTalentPoints(build.expansionCode);
  if (_pointsSpentAlongside(build, talent.talentTreeId) >= maxPoints) {
    return false;
  }

  final pointsInTree = build.pointsSpentPerTree[talent.talentTreeId];
  if (pointsInTree < _pointsRequired(talent)) return false;

  if (talent.dependencyId != null) {
    final dependency = build.talentTreeTalents[talent.talentTreeId].firstWhere(
      (t) => t.id == talent.dependencyId,
    );
    if (dependency.currentRank < _ranksRequiredOf(dependency)) return false;
  }

  return true;
}

/// Whether [talent] can lose a point. Only the most recently spent point on its
/// side of the build can be undone, so Legacy perks don't hold talents back, and
/// only if every remaining talent in the tree stays valid. Imported points have
/// no order, so once nothing was spent after them any of them can go.
bool canRemovePoint(ClassBuild build, Talent talent) {
  if (talent.currentRank <= 0) return false;
  final legacy = isLegacyTree(talent.talentTreeId);
  final lastOnSide = build.buildSequence
      .where((point) => isLegacyTree(point.treeId) == legacy)
      .lastOrNull;
  if (lastOnSide == null) return _isLegalWithout(build, talent);
  if (lastOnSide.talentId != talent.id) return false;

  final tree = build.talentTreeTalents[talent.talentTreeId];

  // A talent that depends on this one needs it to keep its required rank.
  if (talent.currentRank <= _ranksRequiredOf(talent) &&
      tree.any((t) => t.dependencyId == talent.id && t.currentRank > 0)) {
    return false;
  }

  // Every talent still invested needs its row's points to stay spent.
  final pointsAfter = build.pointsSpentPerTree[talent.talentTreeId] - 1;
  for (final t in tree) {
    final ranksAfter = t.id == talent.id ? t.currentRank - 1 : t.currentRank;
    if (ranksAfter > 0 && pointsAfter < _pointsRequired(t)) return false;
  }

  return true;
}

bool _isLegalWithout(ClassBuild build, Talent talent) {
  talent.currentRank--;
  build.pointsSpentPerTree[talent.talentTreeId]--;
  final legal = ranksAreLegal(build);
  talent.currentRank++;
  build.pointsSpentPerTree[talent.talentTreeId]++;
  return legal;
}

/// Whether [build]'s ranks could have been reached by spending points one at a
/// time under the rules above, for a build with ranks but no order. Spending only
/// ever unlocks more apart from the point cap, which depends on the total alone,
/// so spending whatever is allowed until nothing changes finds an order if one
/// exists.
bool ranksAreLegal(ClassBuild build) {
  final talents = build.talentTreeTalents.expand((tree) => tree).toList();
  final ranks = {for (final t in talents) t: t.currentRank};
  final points = build.pointsSpentPerTree;
  try {
    for (final t in talents) {
      t.currentRank = 0;
    }
    build.pointsSpentPerTree = List.filled(points.length, 0);

    var spent = true;
    while (spent) {
      spent = false;
      for (final t in talents) {
        if (t.currentRank < ranks[t]! && isTalentEnabled(build, t)) {
          t.currentRank++;
          build.pointsSpentPerTree[t.talentTreeId]++;
          spent = true;
        }
      }
    }
    return talents.every((t) => t.currentRank == ranks[t]);
  } finally {
    ranks.forEach((t, rank) => t.currentRank = rank);
    build.pointsSpentPerTree = points;
  }
}
