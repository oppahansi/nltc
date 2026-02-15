// Package Imports
import "package:riverpod_annotation/riverpod_annotation.dart";

// Project Imports
import "package:ltc/core/models/data_entities.dart";
import "package:ltc/core/providers/settings_service_provider.dart";
import "package:ltc/core/repos/data_repo.dart";

part "data_providers.g.dart";

@Riverpod(keepAlive: true)
Future<List<Expansion>> expansions(Ref ref) async {
  ref.watch(settingsProvider);

  final settings = ref.watch(settingsProvider).value!;
  final repo = DataRepo();
  final list = await repo.getExpansions(
    languageCode: settings.locale.languageCode,
  );

  list.sort((a, b) => a.id.compareTo(b.id));

  return list;
}

@Riverpod(keepAlive: true)
Future<List<Class>> classes(Ref ref) async {
  ref.watch(settingsProvider);

  final settings = ref.watch(settingsProvider).value!;
  final expansions = await ref.watch(expansionsProvider.future);
  final expansion = expansions.firstWhere(
    (e) => e.id == settings.selectedExpId,
    orElse: () => expansions.first,
  );

  final repo = DataRepo();
  final list = await repo.getClassesByExpansion(
    expansion.id,
    languageCode: settings.locale.languageCode,
  );

  list.sort((a, b) => a.id.compareTo(b.id));

  return list;
}
