// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";

// Project Imports
import "package:ltc/core/settings/setting_keys.dart";
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/game/data_providers.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/core/widgets/shared.dart";
import "package:ltc/l10n/app_localizations.dart";

class ClassSelection extends ConsumerWidget {
  const ClassSelection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);
    final loc = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider).value!;
    final selectedClass = settings.selectedClass;
    final expColor = settings.expColor;
    final themeTextColor = settings.classColor;

    final titleStyle = isTablet(context) || isLargeTablet(context)
        ? displaySmall(context).withColor(expColor)
        : titleLarge(context).withColor(expColor);
    final dropDownStyle = isTablet(context) || isLargeTablet(context)
        ? titleLarge(context)
        : bodyLarge(context);

    return classesAsync.when(
      data: (classes) {
        // Deduplicate by id to avoid multiple DropdownMenuItems matching the same logical class
        final dedupedClasses = <int, Class>{
          for (final c in classes) c.id: c,
        }.values.toList();

        // Find the matching instance inside deduped list; fall back safely if missing
        Class? currentValue = dedupedClasses.firstWhere(
          (c) => c.id == selectedClass.id,
          orElse: () =>
              dedupedClasses.isNotEmpty ? dedupedClasses.first : selectedClass,
        );

        // If the originally selected class is no longer present, update provider to keep state consistent
        if (!dedupedClasses.any((c) => c.id == selectedClass.id) &&
            dedupedClasses.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await ref
                .read(settingsProvider.notifier)
                .setSetting(
                  settingsKeySelectedClassId,
                  dedupedClasses.first.id.toString(),
                );
          });
        }

        return [
          loc.wow_class.capitalize().text(style: titleStyle),
          gapSize(context).gapColumn,
          DropdownButtonHideUnderline(
                child: DropdownButton<Class>(
                  isDense: false,
                  icon: Symbols.arrow_drop_down.iconColored(themeTextColor),

                  iconSize: gapSize(context) * 1.5,
                  value: currentValue,
                  dropdownColor: Colors.black,
                  style: titleLarge(context).withColor(themeTextColor),
                  items: dedupedClasses.map((clazz) {
                    final name =
                        clazz.names[settings.locale.languageCode] ??
                        clazz.names.values.first;

                    return DropdownMenuItem<Class>(
                      value: clazz,
                      child: [
                        Image.asset(
                          "assets/images/icons/classicon_${clazz.code}.webp",
                          width: gapSize(context) * 2.5,
                          height: gapSize(context) * 2.5,
                        ).paddingRight(gapSize(context)),
                        (gapSize(context) * 2).gapColumn,
                        name.text(
                          style: dropDownStyle.withColor(clazz.color.toColor()),
                        ),
                      ].row(crossAxisAlignment: CrossAxisAlignment.center),
                    );
                  }).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    await ref
                        .read(settingsProvider.notifier)
                        .setSetting(
                          settingsKeySelectedClassId,
                          v.id.toString(),
                        );
                  },
                ),
              )
              .paddingAll(gapSize(context))
              .container(decoration: getDefaultBoxDecoration(expColor)),
        ].column();
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          "${loc.failed_to_load_builds} $error",
          style: bodyLarge(context).withColor(Colors.red),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
