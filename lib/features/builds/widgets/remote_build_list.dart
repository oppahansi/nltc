// Dart Imports
import "dart:convert";
import "dart:io";

// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";

// Project Imports
import "package:ltc/core/providers/settings_service_provider.dart";
import "package:ltc/core/utils/colors.dart";
import "package:ltc/core/utils/constants.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/features/builds/providers/builds_providers.dart";
import "package:ltc/features/calculator/models/class_build.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/features/calculator/talent_calculator_screen.dart";
import "package:ltc/l10n/app_localizations.dart";

class RemoteBuildsList extends ConsumerWidget {
  const RemoteBuildsList({super.key});

  String _pointsDist(ClassBuild b) => b.pointsSpentPerTree.join("/");

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value!;
    final remoteBuildsAsync = ref.watch(remoteClassBuildsProvider);
    final loc = AppLocalizations.of(context)!;
    final expColor = settings.expColor;

    return remoteBuildsAsync.when(
      data: (remoteBuilds) {
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: remoteBuilds.length,
          separatorBuilder: (_, _) =>
              Divider(color: Colors.white12, height: 1),
          itemBuilder: (_, i) {
            final remoteBuild = remoteBuilds[i];
            final title = remoteBuild.title.isNotEmpty
                ? remoteBuild.title
                : "Spec ${i + 1}";

            return ListTile(
              dense: true,
              title: title.text(
                style: bodyMedium(context).withColor(
                  classColors[remoteBuild.className.toLowerCase().replaceAll(
                        " ",
                        "",
                      )]!
                      .toColor(),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle:
                  "${remoteBuild.className.capitalize()} • ${_pointsDist(remoteBuild)}"
                      .text(
                        style: bodySmall(context).withColor(Colors.white70),
                      ),
              trailing: Symbols.arrow_forward_ios.icon(
                size: 14,
                color: Colors.white54,
              ),
              onTap: () async {
                final build = remoteBuild;
                if (settings.selectedExpId != build.expansionId) {
                  await ref
                      .read(settingsProvider.notifier)
                      .setSetting(
                        settingsKeySelectedExpId,
                        build.expansionId.toString(),
                      );
                }
                if (settings.selectedClassId != build.classId) {
                  await ref
                      .read(settingsProvider.notifier)
                      .setSetting(
                        settingsKeySelectedClassId,
                        build.classId.toString(),
                      );
                }
                await ref
                    .read(buildStateProvider.notifier)
                    .loadExternalBuild(build);

                if (context.mounted) {
                  context.pushNamed(TalentCalculatorScreen.path);
                }
              },
            );
          },
        ).container(
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(200),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
      loading: () => [
        "${loc.loading.capitalize()}...".text(
          style: bodyMedium(context).withColor(expColor),
        ),
        gapSize(context).gapRow,
        CircularProgressIndicator(color: expColor),
      ].row().center().marginBottom(gapSize(context)),
      error: (e, st) => _extractApiDetail(context, e)
          .text(style: bodyMedium(context).withColor(Colors.redAccent))
          .paddingAll(gapSize(context)),
    );
  }

  String _extractApiDetail(BuildContext context, Object e) {
    if (e is SocketException) {
      return AppLocalizations.of(context)!.failed_to_load_builds;
    }

    final s = e.toString();
    final brace = s.indexOf("{");
    if (brace != -1) {
      final jsonPart = s.substring(brace);
      try {
        final decoded = jsonDecode(jsonPart);
        if (decoded is Map && decoded["detail"] is String) {
          final detail = (decoded["detail"] as String).trim();
          if (detail.isNotEmpty) return detail;
        }
      } catch (_) {}
    }
    return s;
  }
}
