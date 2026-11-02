// Dart Imports
import "dart:math" as math;

// Flutter Imports
import "package:flutter/material.dart";

// Project Imports
import "package:ltc/core/models/data_entities.dart";

String getBgImage(String name) {
  return "assets/images/bgs/$name.webp";
}

void precacheBgs(BuildContext context, List<TalentTree> trees) {
  for (final tree in trees) {
    precacheImage(AssetImage(getBgImage(tree.background)), context);
  }
}

int computeUsedRows(List<Talent> talents) {
  if (talents.isEmpty) return 0;
  final maxRow = talents.map((t) => t.row).reduce(math.max);
  return maxRow + 1;
}

Map<Talent, Offset> getTalentCenters(
  List<Talent> talents,
  double cellWidth,
  double cellHeight,
) {
  return <Talent, Offset>{
    for (final t in talents)
      t: Offset((t.column + 0.5) * cellWidth, (t.row + 0.5) * cellHeight),
  };
}

Map<Talent, List<Talent>> getTalentSupports(List<Talent> talents) {
  return {for (final t in talents) t: t.supports ?? const []};
}

