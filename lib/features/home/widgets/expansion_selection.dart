// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/edition.dart";
import "package:ltc/core/game/editions.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/settings/data_providers.dart";
import "package:ltc/core/settings/setting_keys.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/features/home/widgets/expansion_chip.dart";
import "package:ltc/l10n/app_localizations.dart";

class ExpansionSelection extends ConsumerWidget {
  const ExpansionSelection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expansionsAsync = ref.watch(expansionsProvider);
    final settings = ref.watch(settingsProvider).value!;
    final selectedExp = settings.selectedExp;
    final loc = AppLocalizations.of(context)!;
    final expColor = settings.expColor;
    final style = isTablet(context) || isLargeTablet(context)
        ? displaySmall(context)
        : titleLarge(context);

    return expansionsAsync.when(
      data: (expansions) {
        Future<void> select(Expansion exp) => ref
            .read(settingsProvider.notifier)
            .setSetting(settingsKeySelectedExpId, exp.id.toString());

        final editions = availableEditions(expansions);
        final shown = expansions.where((e) => e.edition == selectedExp.edition);

        return [
          loc.expansion.capitalize().text(style: style.withColor(expColor)),
          gapSize(context).gapColumn,
          if (editions.length > 1) ...[
            SegmentedButton<Edition>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                foregroundColor: Colors.grey,
                selectedForegroundColor: Colors.black,
                selectedBackgroundColor: expColor,
                side: BorderSide(color: expColor),
              ),
              segments: [
                for (final edition in editions)
                  ButtonSegment(
                    value: edition,
                    label: Text(_editionLabel(loc, edition)),
                  ),
              ],
              selected: {selectedExp.edition},
              onSelectionChanged: (selection) => select(
                expansionAfterSwitch(expansions, selectedExp, selection.first),
              ),
            ),
            gapSize(context).gapColumn,
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: shown.map((exp) {
              return ExpansionChip(
                label: eraLabel(exp.era ?? exp.code),
                iconAsset:
                    "assets/images/icons/${exp.era ?? exp.code}_icon.webp",
                selected: selectedExp.id == exp.id,
                onTap: () => select(exp),
              );
            }).toList(),
          ),
        ].column();
      },
      loading: () => CircularProgressIndicator().center(),
      error: (error, stack) => loc.failed_to_load_builds
          .text(style: bodyLarge(context).withColor(Colors.red))
          .center(),
    );
  }

  String _editionLabel(AppLocalizations loc, Edition edition) =>
      switch (edition) {
        Edition.original => loc.edition_original,
        Edition.classic => loc.edition_classic,
        Edition.forever => loc.edition_forever,
      };
}
