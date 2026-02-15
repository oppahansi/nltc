// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/models/data_entities.dart";
import "package:ltc/core/providers/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/features/calculator/utils/utility_methods.dart";
import "package:ltc/features/calculator/widgets/talent_tree_content.dart";
import "package:ltc/l10n/app_localizations.dart";

class TalentTreeView extends ConsumerStatefulWidget {
  final TalentTree tree;
  const TalentTreeView({super.key, required this.tree});

  @override
  ConsumerState<TalentTreeView> createState() => _TalentTreeViewState();
}

class _TalentTreeViewState extends ConsumerState<TalentTreeView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider).value!;
    final classBuildAsync = ref.watch(buildStateProvider);

    final background = getBgImage(widget.tree.background);
    final classColor = settings.classColor;

    return classBuildAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => "${loc.error} $e".text().center(),
      data: (classBuild) {
        final pointsInTree = classBuild.pointsSpentPerTree[widget.tree.id];
        final first = classBuild.pointsSpentPerTree[0];
        final second = classBuild.pointsSpentPerTree[1];
        final third = classBuild.pointsSpentPerTree[2];
        final spentPointState = "($first/$second/$third)";
        final summaryRow =
            [
                  "${widget.tree.names[settings.locale.languageCode]} ($pointsInTree)"
                      .text(style: bodySmall(context).withColor(classColor)),

                  spentPointState.text(
                    style: bodySmall(context).withColor(classColor),
                  ),
                ]
                .row(mainAxisAlignment: MainAxisAlignment.spaceEvenly)
                .container(
                  decoration: BoxDecoration(color: Colors.black.withAlpha(100)),
                )
                .paddingAll(gapSizeSmall(context));

        return Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                child: Image.asset(
                  background,
                  key: ValueKey(background),
                  fit: BoxFit.fill,
                  color: Colors.black.withAlpha(150),
                  colorBlendMode: BlendMode.darken,
                  gaplessPlayback: true,
                ),
              ),
            ),
            [TreeContent(widget.tree).expanded1, summaryRow].column(),
          ],
        );
      },
    );
  }
}
