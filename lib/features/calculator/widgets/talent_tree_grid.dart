// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/features/calculator/utils/utility_methods.dart";
import "package:ltc/features/calculator/widgets/talent_widget.dart";

class TreeGrid extends ConsumerWidget {
  const TreeGrid({super.key, required this.tree, required this.talents});

  final TalentTree tree;
  final List<Talent> talents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value!;
    final usedRows = computeUsedRows(talents);
    final talentPositions = _getTalentPositions();

    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      primary: false,
      shrinkWrap: true,
      itemCount: usedRows * maxColumns,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: maxColumns,
      ),
      itemBuilder: (context, index) {
        final row = index ~/ maxColumns;
        final col = index % maxColumns;
        final talent = talentPositions[Offset(col.toDouble(), row.toDouble())];

        if (talent == null) {
          return const SizedBox.shrink();
        }

        final labelStyle = (isTablet(context) || isLargeTablet(context))
            ? titleLarge(context).withColor(
                talent.currentRank < talent.ranks.length
                    ? Colors.green
                    : Colors.amber,
              )
            : labelSmall(context).withColor(
                talent.currentRank < talent.ranks.length
                    ? Colors.green
                    : Colors.amber,
              );

        final orderLabelStyle = (isTablet(context) || isLargeTablet(context))
            ? bodyMedium(context).withColor(settings.classColor)
            : bodySmall(context).withColor(settings.classColor);

        final buildStateAsync = ref.watch(buildStateProvider);
        final buildState = buildStateAsync.value;
        final Map<int, List<int>> buildOrderMap = {};
        if (buildState != null) {
          // Legacy perks aren't part of the leveling order, so each side counts
          // on its own.
          var order = 0;
          for (final step in buildState.buildSequence) {
            if (isLegacyTree(step.treeId) != isLegacyTree(tree.id)) continue;
            buildOrderMap.putIfAbsent(step.talentId, () => []).add(++order);
          }
        }

        final orderNumbers = buildOrderMap[talent.id] ?? const <int>[];
        final orderTextRaw = orderNumbers.join(",");
        final orderText = orderTextRaw.replaceAll(",", ",\u200B");
        final screenPercent = 0.15;
        final width = screenWidth(context, screenPercent);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            TalentWidget(talent: talent),
            if (talent.currentRank > 0)
              IgnorePointer(
                ignoring: true,
                child:
                    CircleAvatar(
                      radius: screenWidth(context, 0.03),
                      backgroundColor: Colors.black,
                      child: "${talent.currentRank}".text(style: labelStyle),
                    ).container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: talent.currentRank < talent.ranks.length
                              ? Colors.green
                              : Colors.amber,
                          width: 2,
                        ),
                      ),
                    ),
              ).positioned(
                bottom: -gapSizeSmall(context),
                right: -gapSizeSmall(context),
              ),
            if (settings.showOrderNumbers && orderNumbers.isNotEmpty)
              IgnorePointer(
                ignoring: true,
                child: orderText
                    .text(style: orderLabelStyle)
                    .container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                      ),
                    ),
              ).positioned(left: 0, top: -gapSize(context), width: width),
          ],
        ).center();
      },
    );
  }

  Map<Offset, Talent> _getTalentPositions() {
    return {
      for (var t in talents) Offset(t.column.toDouble(), t.row.toDouble()): t,
    };
  }
}
