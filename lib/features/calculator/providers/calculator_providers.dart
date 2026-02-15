// Package Imports
import "package:riverpod_annotation/riverpod_annotation.dart";

// Project Imports
import "package:ltc/features/calculator/models/class_build.dart";
import "package:ltc/features/calculator/repos/class_builds_repo.dart";

part "calculator_providers.g.dart";

@Riverpod(keepAlive: true)
class TreeIndex extends _$TreeIndex {
  @override
  int build() => 0;
  void setTreeIndex(int value) => state = value;
}

@riverpod
Future<List<ClassBuild>> savedBuilds(Ref ref, int limit) async {
  final repo = ClassBuildsRepo();
  return repo.listBuilds(includeBuildPoints: false, limit: limit);
}
