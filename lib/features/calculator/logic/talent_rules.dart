// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/talent_build/class_build.dart";

const pointsPerRow = 5;

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
  if (pointsInTree < talent.row * pointsPerRow) return false;

  if (talent.dependencyId != null) {
    final dependency = build.talentTreeTalents[talent.talentTreeId].firstWhere(
      (t) => t.id == talent.dependencyId,
    );
    if (dependency.currentRank < dependency.ranks.length) return false;
  }

  return true;
}

/// Whether [talent] can lose a point. Only the most recently spent point on its
/// side of the build can be undone, so Legacy perks don't hold talents back, and
/// only if every remaining talent in the tree stays valid.
bool canRemovePoint(ClassBuild build, Talent talent) {
  if (talent.currentRank <= 0) return false;
  final legacy = isLegacyTree(talent.talentTreeId);
  final lastOnSide = build.buildSequence
      .where((point) => isLegacyTree(point.treeId) == legacy)
      .lastOrNull;
  if (lastOnSide?.talentId != talent.id) return false;

  final tree = build.talentTreeTalents[talent.talentTreeId];

  // A talent that depends on this one needs it to stay full.
  if (tree.any((t) => t.dependencyId == talent.id && t.currentRank > 0)) {
    return false;
  }

  // Every talent still invested needs its row's points to stay spent.
  final pointsAfter = build.pointsSpentPerTree[talent.talentTreeId] - 1;
  for (final t in tree) {
    final ranksAfter = t.id == talent.id ? t.currentRank - 1 : t.currentRank;
    if (ranksAfter > 0 && pointsAfter < t.row * pointsPerRow) return false;
  }

  return true;
}
