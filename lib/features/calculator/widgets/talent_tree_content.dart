// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/models/data_entities.dart";
import "package:ltc/core/providers/settings_service_provider.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/features/calculator/utils/utility_methods.dart";
import "package:ltc/features/calculator/widgets/talent_dependency_painter.dart";
import "package:ltc/features/calculator/widgets/talent_tree_grid.dart";

class TreeContent extends ConsumerWidget {
  const TreeContent(this.tree, {super.key});
  final TalentTree tree;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value!;
    final buildStateAsync = ref.watch(buildStateProvider);

    return buildStateAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text("Error $e")),
      data: (buildState) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Use this.tree directly (do not depend on treeIndex for displayed talents)
            final talents = buildState.talentTreeTalents[tree.id];
            final cellWidth = constraints.maxWidth / maxColumns;
            final cellHeight = cellWidth;
            final usedRows = computeUsedRows(talents);
            final totalHeight = cellHeight * usedRows;
            final centers = getTalentCenters(talents, cellWidth, cellHeight);
            final supports = getTalentSupports(talents);

            final content = SizedBox(
              width: constraints.maxWidth,
              height: totalHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: TalentDependencyPainter(
                          buildState: ref.read(buildStateProvider.notifier),
                          supports: supports,
                          centers: centers,
                          expColor: settings.expColor,
                          arrowHeadSize: _getArrowHeadSize(context),
                          arrowOffset: _getArrowOffset(context),
                          strokeWidth: _getStrokeWidth(context),
                        ),
                      ),
                    ),
                  ),
                  TreeGrid(tree: tree, talents: talents),
                ],
              ),
            );

            if (totalHeight > constraints.maxHeight) {
              return SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: content,
              );
            }
            return content;
          },
        );
      },
    );
  }

  double _getArrowHeadSize(BuildContext context) {
    return screenWidth(context, 0.05);
  }

  double _getArrowOffset(BuildContext context) {
    return screenWidth(context, 0.055);
  }

  double _getStrokeWidth(BuildContext context) {
    return screenWidth(context, 0.02);
  }
}
