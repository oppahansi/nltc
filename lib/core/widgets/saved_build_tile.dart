// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:share_plus/share_plus.dart";

// Project Imports
import "package:ltc/core/talent_build/saved_builds_provider.dart";
import "package:ltc/core/settings/setting_keys.dart";
import "package:ltc/core/game/game_colors.dart";
import "package:ltc/core/navigation/route_paths.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/talent_build/share_util.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/core/talent_build/class_build.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/l10n/app_localizations.dart";

class SavedBuildTile extends ConsumerWidget {
  final ClassBuild classBuild;
  final int limit;

  const SavedBuildTile({
    super.key,
    required this.classBuild,
    required this.limit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value!;
    final selectedExp = settings.selectedExp;
    final expColor = settings.expColor;
    final loc = AppLocalizations.of(context)!;

    final title = classBuild.title.isNotEmpty
        ? classBuild.title
        : classBuild.className.capitalize();
    final subTitle =
        "${classBuild.className.capitalize()} • ${classBuild.expansionCode.capitalize()}";

    final deleteButton = IconButton(
      tooltip: loc.delete.capitalize(),
      icon: Symbols.delete.icon(
        size: gapSize(context),
        color: Colors.redAccent,
      ),
      onPressed: () async {
        final ok = await _deleteConfirmation(context, ref);
        if (ok == true) {
          await ref
              .read(buildStateProvider.notifier)
              .deleteBuild(classBuild.id!);

          ref.invalidate(savedBuildsProvider(limit + 1));

          if (context.mounted) {
            context.showSnackBar(SnackBar(content: loc.build_deleted.text()));
          }
        }
      },
    );

    final linkButton = IconButton(
      icon: Symbols.link.icon(color: expColor, size: gapSize(context)),
      tooltip: loc.share_build_url,
      onPressed: () {
        SharePlus.instance.share(ShareParams(text: buildShareUrl(classBuild)));
      },
    );

    final shareButton = IconButton(
      icon: Symbols.share.icon(color: expColor, size: gapSize(context)),
      tooltip: loc.share_build_code,
      onPressed: () {
        SharePlus.instance.share(ShareParams(text: buildShareCode(classBuild)));
      },
    );

    return ListTile(
      dense: true,
      title: title.text(
        style: bodyMedium(
          context,
        ).withColor(expColors[classBuild.expansionCode]!.first),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: subTitle.text(
        style: bodySmall(context).withColor(classBuild.getClassColor()),
      ),
      trailing: [
        deleteButton,
        if (classBuild.expansionCode != "vanilla") linkButton,
        shareButton,
        Symbols.arrow_forward.icon(color: expColor),
      ].row(mainAxisSize: MainAxisSize.min),
      onTap: () async {
        if (classBuild.id == null || classBuild.id! < 0) return;
        if (selectedExp.id != classBuild.expansionId) {
          await ref
              .read(settingsProvider.notifier)
              .setSetting(
                settingsKeySelectedExpId,
                classBuild.expansionId.toString(),
              );
        }
        if (settings.selectedClassId != classBuild.classId) {
          await ref
              .read(settingsProvider.notifier)
              .setSetting(
                settingsKeySelectedClassId,
                classBuild.classId.toString(),
              );
        }
        await ref
            .read(buildStateProvider.notifier)
            .loadSavedBuild(classBuild.id!);

        if (context.mounted) {
          context.pushNamed(RoutePaths.calculator);
        }
      },
    );
  }

  Future<bool?> _deleteConfirmation(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider).value!;
    final expColor = settings.expColor;

    final cancelButton = TextButton(
      onPressed: () => Navigator.pop(context, false),
      child: loc.cancel.capitalize().text(
        style: bodyMedium(context).withColor(expColor.withAlpha(150)),
      ),
    );
    final deleteButton = TextButton(
      onPressed: () => Navigator.pop(context, true),
      child: loc.delete.capitalize().text(
        style: bodyMedium(context).withColor(Colors.redAccent),
      ),
    );

    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black87,
        title: loc.delete_build.text(
          style: titleLarge(context).withColor(Colors.redAccent),
        ),
        content:
            "${loc.delete.capitalize()} '${(classBuild.title.isEmpty ? classBuild.className.capitalize() : classBuild.title)}'?"
                .text(style: bodyMedium(context).withColor(Colors.white70)),
        actions: [cancelButton, deleteButton],
      ),
    );
  }
}
