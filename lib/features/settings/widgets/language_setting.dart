// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";

// Project Imports
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/core/widgets/shared.dart";
import "package:ltc/l10n/app_localizations.dart";

class LanguageSetting extends ConsumerWidget {
  const LanguageSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value!;
    final settingsAsync = ref.watch(settingsProvider);
    final loc = AppLocalizations.of(context)!;
    final expColor = settings.expColor;

    final languageNames = <String, String>{
      "en": loc.english.capitalize(),
      "de": loc.german.capitalize(),
    };

    return settingsAsync.when(
      data: (settings) {
        final currentLocale = settings.locale;
        final supportedLocales = AppLocalizations.supportedLocales;

        return ListTile(
          leading: Symbols.language.icon(color: expColor),
          title: loc.language.capitalize().text(
            style: bodyMedium(context).withColor(expColor),
          ),
          subtitle: languageNames[currentLocale.languageCode]!.text(
            style: bodySmall(context).withColor(expColor.withAlpha(175)),
          ),
          trailing: Symbols.chevron_right.icon(color: expColor),
          onTap: () async {
            final selected = await showModalBottomSheet<Locale>(
              context: context,
              backgroundColor: Colors.black.withAlpha(200),
              builder: (context) => [
                for (final locale in supportedLocales)
                  ListTile(
                    leading: Icon(
                      locale.languageCode == currentLocale.languageCode
                          ? Symbols.radio_button_checked
                          : Symbols.radio_button_unchecked,
                      color: expColor,
                    ),
                    title: languageNames[locale.languageCode]!.text(
                      style: bodyMedium(context).withColor(expColor),
                    ),
                    onTap: () => Navigator.pop(context, locale),
                  ),
              ].column(mainAxisSize: MainAxisSize.min),
            );

            if (selected != null && selected != currentLocale) {
              await ref
                  .read(settingsProvider.notifier)
                  .setSetting("locale", selected.languageCode);
            }
          },
        ).container(decoration: getDefaultBoxDecoration(expColor));
      },
      loading: () => ListTile(
        leading: const Icon(Symbols.language),
        title: Text(loc.language),
        subtitle: Text("${"loc.loading"}..."),
      ),
      error: (e, st) => ListTile(
        leading: const Icon(Symbols.language),
        title: Text(loc.language),
        subtitle: Text("Error: $e"),
      ),
    );
  }
}
