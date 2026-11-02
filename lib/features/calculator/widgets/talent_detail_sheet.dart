// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/material_symbols_icons.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/l10n/app_localizations.dart";

class TalentDetailSheet extends ConsumerStatefulWidget {
  final Talent talent;
  const TalentDetailSheet({super.key, required this.talent});

  @override
  ConsumerState<TalentDetailSheet> createState() => _TalentDetailSheetState();
}

class _TalentDetailSheetState extends ConsumerState<TalentDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final buildState = ref.read(buildStateProvider.notifier);
    final settings = ref.watch(settingsProvider).value!;
    final loc = AppLocalizations.of(context)!;

    final expColor = settings.expColor;
    final classColor = settings.classColor;

    ref.watch(buildStateProvider);

    final talent = widget.talent;
    final enabled = buildState.isTalentEnabled(talent);
    final canRemove = buildState.canRemovePoint(talent: talent);
    final currentRank = talent.currentRank;
    final maxRank = talent.ranks.length;
    final talentImageWidth = screenWidth(context, 0.15);

    String currentDesc = "";
    String nextDesc = "";

    if (talent.ranks.isNotEmpty) {
      if (currentRank > 0 && currentRank <= talent.ranks.length) {
        currentDesc = talent
            .ranks[currentRank - 1]
            .descriptions[settings.locale.languageCode]!;
      } else {
        currentDesc =
            talent.ranks.first.descriptions[settings.locale.languageCode]!;
      }
      if (currentRank < maxRank &&
          currentRank >= 0 &&
          currentRank < talent.ranks.length) {
        nextDesc = talent
            .ranks[currentRank]
            .descriptions[settings.locale.languageCode]!;
      }
    }

    return DraggableScrollableSheet(
      expand: false,
      minChildSize: 0.35,
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: [
          [
            Image.asset(
              "assets/images/icons/${talent.icon.toLowerCase()}.webp",
              width: talentImageWidth,
              height: talentImageWidth,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Symbols.help_outline.icon(color: Colors.white),
            ).container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: currentRank >= maxRank
                      ? expColor
                      : (enabled ? Colors.green : Colors.grey),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            gapSize(context).gapRow,
            [
              talent.names[settings.locale.languageCode]!.text(
                style: titleLarge(
                  context,
                ).withColor(classColor).withWeight(FontWeight.bold),
              ),
              "${loc.rank.capitalize()} $currentRank / $maxRank".text(
                style: bodySmall(context)?.withColor(Colors.grey[300]!),
              ),
            ].column(crossAxisAlignment: CrossAxisAlignment.start).expanded1,
            IconButton(
              icon: Symbols.close.icon(color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ].row(crossAxisAlignment: CrossAxisAlignment.center),
          gapSize(context).gapColumn,
          if (currentDesc.isNotEmpty)
            currentDesc.text(
              style: bodyMedium(context)?.withColor(Colors.white),
            ),
          if (nextDesc.isNotEmpty) ...[
            gapSize(context).gapColumn,
            loc.next_rank.text(
              style: bodyMedium(
                context,
              )?.withColor(Colors.amber[300]!)?.withWeight(FontWeight.w600),
            ),
            gapSizeSmall(context).gapColumn,
            nextDesc.text(
              style: bodyMedium(context)?.withColor(Colors.white70),
            ),
          ],
          if (talent.ranks.length > 1) ...[
            gapSize(context).gapColumn,
            ExpansionTile(
              title: loc.all_ranks.text(
                style: titleSmall(
                  context,
                )?.withColor(classColor)?.withWeight(FontWeight.w500),
              ),
              iconColor: classColor,
              collapsedIconColor: classColor,
              tilePadding: EdgeInsets.zero,
              children: [
                ...List.generate(
                  talent.ranks.length,
                  (i) =>
                      "${loc.rank.capitalize()} ${i + 1}: \n${talent.ranks[i].descriptions[settings.locale.languageCode]}\n"
                          .text(
                            style: bodyMedium(context)?.withColor(
                              i + 1 == currentRank
                                  ? Colors.greenAccent
                                  : Colors.white70,
                            ),
                          ),
                ),
              ],
            ),
          ],
          gapSize(context).gapColumn,
          [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: Colors.grey[700],
                backgroundColor: expColor,
                disabledIconColor: Colors.grey,
                iconColor: Colors.black,
                textStyle: bodyMedium(
                  context,
                ).withColor(Colors.black).withWeight(FontWeight.bold),
              ),
              onPressed: enabled && currentRank < maxRank
                  ? () => buildState.addPoint(talent)
                  : null,
              icon: Icons.add.icon(color: Colors.black),
              label: loc.add.capitalize().text(
                style: bodyMedium(
                  context,
                ).withColor(Colors.black).withWeight(FontWeight.bold),
              ),
            ).expanded1,
            gapSizeSmall(context).gapRow,
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: Colors.grey[700],
                  backgroundColor: Colors.redAccent,
                  disabledIconColor: Colors.grey,
                  iconColor: Colors.black,
                  textStyle: bodyMedium(
                    context,
                  ).withColor(Colors.black).withWeight(FontWeight.bold),
                ),
                onPressed: canRemove
                    ? () => buildState.removePoint(talent)
                    : null,
                icon: Symbols.remove.icon(color: Colors.black),
                label: loc.remove.capitalize().text(
                  style: bodyMedium(
                    context,
                  ).withColor(Colors.black).withWeight(FontWeight.bold),
                ),
              ),
            ),
          ].row(),
        ].column(crossAxisAlignment: CrossAxisAlignment.start),
      ).paddingAll(gapSize(context)),
    );
  }
}
