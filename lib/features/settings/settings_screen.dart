// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/providers/settings_service_provider.dart";
import "package:ltc/core/utils/constants.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/features/settings/ex_import_setting.dart";
import "package:ltc/features/settings/language_setting.dart";
import "package:ltc/features/settings/show_order_numbers_setting.dart";
import "package:ltc/l10n/app_localizations.dart";

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String path = "/settings";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value!;
    final loc = AppLocalizations.of(context)!;

    final boxDecoration = BoxDecoration(
      image: DecorationImage(
        image: AssetImage(getRngBgImagePath()),
        fit: BoxFit.cover,
      ),
    );

    final title = loc.settings.capitalize().text(
      style: titleMedium(context).withColor(settings.expColor),
    );

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: boxDecoration,
          child: Padding(
            padding: EdgeInsets.all(gapSize(context)),
            child: Column(
              children: [
                title,
                gapSizeSmall(context).gapColumn,
                const LanguageSetting(),
                gapSizeSmall(context).gapColumn,
                const ShowOrderNumbersSetting(),
                gapSize(context).gapColumn,
                const ExImportSetting(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
