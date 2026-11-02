// Package Imports
import "package:riverpod_annotation/riverpod_annotation.dart";

// Project Imports
import "package:ltc/core/talent_build/class_build.dart";
import "package:ltc/core/talent_build/class_builds_repo.dart";

part "saved_builds_provider.g.dart";

@riverpod
Future<List<ClassBuild>> savedBuilds(Ref ref, int limit) async {
  final repo = ClassBuildsRepo();
  return repo.listBuilds(includeBuildPoints: false, limit: limit);
}
