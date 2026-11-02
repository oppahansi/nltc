// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:share_plus/share_plus.dart";

// Project Imports
import "package:ltc/core/settings/setting_keys.dart";
import "package:ltc/core/navigation/route_paths.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/game/data_providers.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/share_util.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/features/calculator/providers/calculator_providers.dart";
import "package:ltc/features/calculator/widgets/build_sequence_sheet.dart";
import "package:ltc/features/calculator/widgets/save_build_sheet.dart";
import "package:ltc/l10n/app_localizations.dart";

class CalculatorDrawer extends ConsumerWidget {
  const CalculatorDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value!;
    final selectedClass = settings.selectedClass;
    // Ensure we also rebuild once classes reload after a locale change
    ref.watch(classesProvider);

    final expColor = settings.expColor;
    final classColor = settings.classColor;
    final loc = AppLocalizations.of(context)!;

    final buildState = ref.watch(buildStateProvider.notifier);
    final classBuildAsync = ref.watch(buildStateProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final showOrderNumbers = settingsAsync.value?.showOrderNumbers ?? true;

    final langCode =
        settingsAsync.value?.locale.languageCode ??
        selectedClass.names.keys.first;
    final className =
        selectedClass.names[langCode] ?? selectedClass.names.values.first;

    final showBuildNumbersSubTitle = showOrderNumbers
        ? loc.enabled.capitalize()
        : loc.disabled.capitalize();

    return Drawer(
      width: screenWidth(context, 0.75),
      backgroundColor: Colors.black.withAlpha(200),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            child: className
                .capitalize()
                .text(style: headlineMedium(context).withColor(classColor))
                .center(),
          ),
          ListTile(
            leading: Symbols.reset_settings.icon(color: expColor),
            title: loc.reset.capitalize().text(
              style: bodyMedium(context).withColor(classColor),
            ),
            onTap: () => buildState.resetBuild(),
          ),
          ListTile(
            leading: Symbols.format_list_numbered.icon(color: expColor),
            title: loc.build_order.capitalize().text(
              style: bodyMedium(context).withColor(classColor),
            ),
            subtitle: showBuildNumbersSubTitle.text(
              style: bodySmall(context).withColor(classColor),
            ),
            trailing: Switch(
              value: showOrderNumbers,
              activeThumbColor: expColor,
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.grey.withAlpha(100),
              onChanged: (v) async {
                await ref
                    .read(settingsProvider.notifier)
                    .setSetting(settingsKeyShowOrderNumbers, v.toString());
              },
            ),
            onTap: () async {
              final v = !showOrderNumbers;
              await ref
                  .read(settingsProvider.notifier)
                  .setSetting(settingsKeyShowOrderNumbers, v.toString());
            },
          ),
          Builder(
            builder: (_) {
              final buildValue = classBuildAsync.value;
              final hasBuild =
                  buildValue != null &&
                  (!buildState.isBuildSequenceEmpty() ||
                      !buildState.isSkillTreeEmpty());
              final shareUrl =
                  (buildValue != null && canShareBuild(buildValue) && hasBuild)
                  ? buildShareUrl(buildValue)
                  : "";
              final shareCode = (buildValue != null && hasBuild)
                  ? buildShareCode(buildValue)
                  : "";
              final shareUrlSubTitle = shareUrl.isEmpty
                  ? (buildValue == null
                        ? loc.loading.capitalize()
                        : canShareBuild(buildValue)
                        ? loc.no_points_spent
                        : loc.unavailable_for_this_expansion)
                  : shareUrl;
              final shareCodeSubTitle = shareCode.isEmpty
                  ? (buildValue == null
                        ? loc.loading.capitalize()
                        : loc.no_points_spent)
                  : shareCode;

              return [
                Divider(color: expColor),
                ListTile(
                  leading: Symbols.link.icon(color: expColor),
                  title: loc.share_build_url.text(
                    style: bodyMedium(context).withColor(classColor),
                  ),
                  subtitle: shareUrlSubTitle.text(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodySmall(
                      context,
                    ).withColor(classColor.withAlpha(180)),
                  ),
                  enabled: shareUrl.isNotEmpty,
                  onTap: shareUrl.isEmpty
                      ? null
                      : () {
                          SharePlus.instance.share(ShareParams(text: shareUrl));
                          context.pop();
                        },
                ),
                ListTile(
                  leading: Symbols.share.icon(color: expColor),
                  title: loc.share_build_code.text(
                    style: bodyMedium(context).withColor(classColor),
                  ),
                  subtitle: shareCodeSubTitle.text(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodySmall(
                      context,
                    ).withColor(classColor.withAlpha(180)),
                  ),
                  enabled: shareCode.isNotEmpty,
                  onTap: shareCode.isEmpty
                      ? null
                      : () {
                          SharePlus.instance.share(
                            ShareParams(text: shareCode),
                          );

                          context.pop();
                        },
                ),
                Divider(color: expColor),
              ].column();
            },
          ),
          ListTile(
            leading: Symbols.save.icon(color: expColor),
            title: loc.save_build.text(
              style: bodyMedium(context).withColor(classColor),
            ),
            onTap: () async {
              if (buildState.isBuildSequenceEmpty() &&
                  buildState.isSkillTreeEmpty()) {
                context.showSnackBar(
                  SnackBar(content: loc.nothing_to_save.text()),
                );
                return;
              }
              final title = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.black87,
                builder: (_) => SaveBuildSheet(),
              );
              if (title == null || title.isEmpty) return;
              try {
                await ref.read(buildStateProvider.notifier).saveBuild(title);
                ref.invalidate(savedBuildsProvider);
                if (context.mounted) {
                  context.pop();
                  context.showSnackBar(
                    SnackBar(content: loc.build_saved(title).text()),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  context.showSnackBar(
                    SnackBar(content: "${loc.error}: $e".text()),
                  );
                }
              }
            },
          ),
          Divider(color: expColor),
          ListTile(
            leading: Symbols.format_list_numbered.icon(color: expColor),
            title: loc.show_build_order.text(
              style: bodyMedium(context).withColor(classColor),
            ),
            onTap: () {
              context.pop();
              showBuildSequenceSheet(context, ref);
            },
          ),
          Divider(color: expColor),
          ListTile(
            leading: Symbols.settings.icon(color: expColor),
            title: loc.settings.capitalize().text(
              style: bodyMedium(context).withColor(classColor),
            ),
            onTap: () {
              context.pushNamed(RoutePaths.settings);
            },
          ),
        ],
      ),
    );
  }

  Future<void> showBuildSequenceSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      isScrollControlled: true,
      builder: (_) => const BuildSequenceSheet(),
    );
  }
}
