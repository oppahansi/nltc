// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/game/game_colors.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/l10n/app_localizations.dart";

class BuildSequenceSheet extends ConsumerWidget {
  const BuildSequenceSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBuild = ref.watch(buildStateProvider);
    final loc = AppLocalizations.of(context)!;

    return asyncBuild.when(
      loading: () => CircularProgressIndicator().center().sizedHeight(200),
      error: (e, _) => "${loc.error.capitalize()} $e"
          .text(style: const TextStyle(color: Colors.red))
          .center()
          .sizedHeight(200),
      data: (classBuild) {
        final sequence = classBuild.buildSequence;
        if (sequence.isEmpty) {
          return loc.no_points_spent
              .text(style: bodyLarge(context).withColor(Colors.white70))
              .center()
              .sizedHeight(200);
        }

        final talentMap = <int, Talent>{
          for (final t in classBuild.talentTreeTalents.expand((v) => v))
            t.id: t,
        };

        // Legacy perks aren't part of the leveling order, so each side has its
        // own order, and its own tab in a build that has both.
        final rankCounters = <int, int>{};
        final talentRows = <_SeqRow>[];
        final legacyRows = <_SeqRow>[];
        for (final bp in sequence) {
          final talent = talentMap[bp.talentId];
          if (talent == null) continue;
          final newRank = (rankCounters.update(
            bp.talentId,
            (v) => v + 1,
            ifAbsent: () => 1,
          ));
          final rows = isLegacyTree(bp.treeId) ? legacyRows : talentRows;
          rows.add(
            _SeqRow(
              index: rows.length + 1,
              talent: talent,
              rankAtStep: newRank,
              maxRank: talent.ranks.length,
              treeIndex: talent.talentTreeId,
            ),
          );
        }

        final hasLegacy = classBuild.talentTrees.any((t) => isLegacyTree(t.id));
        final color = getExpansionColor(classBuild.expansionCode);

        return DefaultTabController(
          length: 2,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            builder: (_, controller) => [
              [
                gapSize(context).gapRow,
                loc.build_order.text(
                  style: titleLarge(context).withColor(Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: Symbols.close.icon(color: Colors.white70),
                  onPressed: () => context.pop(),
                ),
              ].row(),
              if (hasLegacy)
                TabBar(
                  indicatorColor: color,
                  labelColor: color,
                  unselectedLabelColor: Colors.white70,
                  dividerColor: Colors.white12,
                  tabs: [
                    Tab(text: loc.buildOrderTalents),
                    Tab(text: loc.buildOrderLegacy),
                  ],
                ),
              gapSizeSmall(context).gapColumn,
              // One list at a time: the sheet's controller can only drive one, so
              // the tabs switch by tapping rather than by swiping.
              Builder(
                builder: (context) {
                  final tabs = DefaultTabController.of(context);
                  return ListenableBuilder(
                    listenable: tabs,
                    builder: (context, _) {
                      final legacy = hasLegacy && tabs.index == 1;
                      return _SequenceList(
                        key: ValueKey(legacy),
                        rows: legacy ? legacyRows : talentRows,
                        trees: classBuild.talentTrees,
                        color: color,
                        controller: controller,
                      );
                    },
                  );
                },
              ).expanded1,
            ].columnCrossStart(),
          ),
        );
      },
    );
  }
}

class _SequenceList extends ConsumerWidget {
  const _SequenceList({
    super.key,
    required this.rows,
    required this.trees,
    required this.color,
    required this.controller,
  });

  final List<_SeqRow> rows;
  final List<TalentTree> trees;
  final Color color;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider).value!;

    if (rows.isEmpty) {
      return loc.no_points_spent
          .text(style: bodyLarge(context).withColor(Colors.white70))
          .center();
    }

    return ListView.separated(
      controller: controller,
      itemCount: rows.length,
      separatorBuilder: (_, _) => Divider(color: Colors.white12, height: 8),
      itemBuilder: (_, i) {
        final e = rows[i];
        final treeName = trees
            .firstWhere((t) => t.id == e.treeIndex)
            .names[settings.locale.languageCode]!;

        return ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: Colors.black,
            child: e.index.toString().text(
              style: bodySmall(context).withColor(color),
            ),
          ),
          title: e.talent.names[settings.locale.languageCode]!.text(
            style: bodyMedium(context).withColor(Colors.white),
          ),
          subtitle:
              "${loc.rank.capitalize()} ${e.rankAtStep}/${e.maxRank}  •  ${loc.in_tree(treeName)}"
                  .text(style: bodySmall(context).withColor(Colors.white70)),
          trailing: Image.asset(
            "assets/images/icons/${e.talent.icon.toLowerCase()}.webp",
            width: gapSizeLarge(context),
            height: gapSizeLarge(context),
            errorBuilder: (_, _, _) =>
                Symbols.help_outline.icon(color: Colors.white54),
          ),
        );
      },
    );
  }
}

class _SeqRow {
  final int index;
  final Talent talent;
  final int rankAtStep;
  final int maxRank;
  final int treeIndex;
  _SeqRow({
    required this.index,
    required this.talent,
    required this.rankAtStep,
    required this.maxRank,
    required this.treeIndex,
  });
}
