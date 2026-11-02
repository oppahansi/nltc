// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/edition.dart";

/// The editions that have expansions, in display order.
List<Edition> availableEditions(List<Expansion> expansions) => [
  for (final edition in Edition.values)
    if (expansions.any((e) => e.edition == edition)) edition,
];

/// Where switching to [edition] lands: the same era where it exists there,
/// otherwise the edition's first expansion.
Expansion expansionAfterSwitch(
  List<Expansion> expansions,
  Expansion current,
  Edition edition,
) {
  final inEdition = expansions.where((e) => e.edition == edition).toList();
  return inEdition.firstWhere(
    (e) => e.era == current.era,
    orElse: () => inEdition.first,
  );
}
