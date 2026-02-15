// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/providers/settings_service_provider.dart";
import "package:ltc/core/repos/data_providers.dart";
import "package:ltc/core/utils/constants.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/features/home/expansion_chip.dart";
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
        return [
          loc.expansion.capitalize().text(style: style.withColor(expColor)),
          gapSize(context).gapColumn,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: expansions.map((exp) {
              final selected = selectedExp.id == exp.id;

              return ExpansionChip(
                label: exp.code.capitalize(),
                iconAsset: "assets/images/icons/${exp.code}_icon.webp",
                selected: selected,
                onTap: () async {
                  await ref
                      .read(settingsProvider.notifier)
                      .setSetting(settingsKeySelectedExpId, exp.id.toString());
                },
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
}
