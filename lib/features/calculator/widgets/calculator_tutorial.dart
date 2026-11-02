// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";

// Project Imports
import "package:ltc/core/settings/setting_keys.dart";
import "package:ltc/core/settings/settings_service.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/l10n/app_localizations.dart";

Future<void> markCalculatorTutorialSeen() async {
  final settingsService = SettingsService();
  settingsService.setSetting(settingsKeyTutorialSeen, "true");
}

bool hasSeenCalculatorTutorial() {
  final settings = SettingsService.getSettings();
  return settings.tutorialSeen;
}

class CalculatorTutorialSheet extends ConsumerWidget {
  const CalculatorTutorialSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider).value!;
    final classColor = settings.classColor;

    final items = <_StepInfo>[
      _StepInfo(
        icon: Symbols.touch_app,
        title: loc.tutorialAddPoints,
        body: loc.tutorialAddPointsBody,
      ),
      _StepInfo(
        icon: Symbols.info,
        title: loc.tutorialDetailsRanks,
        body: loc.tutorialDetailsRanksBody,
      ),
      _StepInfo(
        icon: Symbols.undo,
        title: loc.tutorialUndo,
        body: loc.tutorialUndoBody,
      ),
      _StepInfo(
        icon: Symbols.auto_fix_high,
        title: loc.tutorialOrderNumbers,
        body: loc.tutorialOrderNumbersBody,
      ),
      _StepInfo(
        icon: Symbols.share,
        title: loc.tutorialShareImport,
        body: loc.tutorialShareImportBody,
      ),
      _StepInfo(
        icon: Symbols.save,
        title: loc.tutorialSaveBuilds,
        body: loc.tutorialSaveBuildsBody,
      ),
      _StepInfo(
        icon: Symbols.device_hub,
        title: loc.tutorialDependencies,
        body: loc.tutorialDependenciesBody,
      ),
      _StepInfo(
        icon: Symbols.splitscreen,
        title: loc.tutorialRowGating,
        body: loc.tutorialRowGatingBody,
      ),
    ];

    return DraggableScrollableSheet(
      expand: false,
      minChildSize: 0.45,
      initialChildSize: 0.62,
      maxChildSize: 0.9,
      builder: (_, controller) => Material(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: CustomScrollView(
          controller: controller,
          slivers: [
            SliverToBoxAdapter(
              child: [
                [
                  loc.tutorialTitle
                      .text(
                        style: titleLarge(
                          context,
                        ).withColor(classColor).withWeight(FontWeight.bold),
                      )
                      .expanded1,
                  IconButton(
                    icon: Symbols.close.icon(color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ].row(),
                const Divider(color: Colors.white24, height: 24),
              ].column().paddingAll(gapSizeSmall(context)),
            ),
            SliverList.separated(
              itemBuilder: (_, i) {
                final step = items[i];
                return [
                  CircleAvatar(
                    backgroundColor: classColor.withAlpha(50),
                    child: step.icon.icon(color: classColor),
                  ),
                  gapSizeSmall(context).gapRow,
                  [
                        step.title.text(
                          style: titleSmall(context)
                              ?.withColor(Colors.white)
                              ?.withWeight(FontWeight.w600),
                        ),
                        gapSizeSmall(context).gapColumn,
                        step.body.text(
                          style: bodySmall(context).withColor(Colors.white70),
                        ),
                      ]
                      .column(crossAxisAlignment: CrossAxisAlignment.start)
                      .expanded1,
                ].row().paddingSymmetric(
                  horizontal: gapSize(context),
                  vertical: gapSizeSmall(context),
                );
              },
              separatorBuilder: (_, _) => const Divider(
                color: Colors.white10,
                height: 20,
              ).paddingSymmetric(horizontal: 8),
              itemCount: items.length,
            ),
            SliverToBoxAdapter(
              child:
                  [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: classColor,
                            foregroundColor: Colors.black,
                            minimumSize: Size(double.infinity, 44),
                          ),
                          icon: Symbols.check_circle.icon(
                            size: gapSize(context),
                          ),
                          onPressed: () {
                            markCalculatorTutorialSeen();
                            Navigator.of(context).pop();
                          },
                          label: loc.tutorialGotIt.text(
                            style: bodyMedium(context)
                                .withColor(Colors.black)
                                .withWeight(FontWeight.bold),
                          ),
                        ),
                      ]
                      .column(crossAxisAlignment: CrossAxisAlignment.stretch)
                      .paddingAll(gapSizeSmall(context)),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: SafeArea(top: false, child: const SizedBox(height: 4)),
            ),
          ],
        ).safeArea(top: false),
      ),
    );
  }
}

class _StepInfo {
  final IconData icon;
  final String title;
  final String body;
  _StepInfo({required this.icon, required this.title, required this.body});
}
