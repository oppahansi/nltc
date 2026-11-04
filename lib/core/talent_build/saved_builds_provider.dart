// Package Imports
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

// Project Imports
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/talent_build/class_build.dart";
import "package:ltc/core/talent_build/class_builds_repo.dart";

part "saved_builds_provider.g.dart";

@riverpod
Future<List<ClassBuild>> savedBuilds(Ref ref, int limit) async {
  // Builds are read in the current language.
  ref.watch(settingsProvider.select((s) => s.value?.locale.languageCode));
  final repo = ClassBuildsRepo();
  return repo.listBuilds(includeBuildPoints: true, limit: limit);
}
