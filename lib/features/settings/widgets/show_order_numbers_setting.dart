// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";

// Project Imports
import "package:ltc/core/game/game_colors.dart";
import "package:ltc/core/settings/setting_keys.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/core/widgets/shared.dart";
import "package:ltc/l10n/app_localizations.dart";

class ShowOrderNumbersSetting extends ConsumerWidget {
  const ShowOrderNumbersSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value!;
    final selectedExp = settings.selectedExp;
    final expColor = settings.expColor;
    final settingsAsync = ref.watch(settingsProvider);
    final loc = AppLocalizations.of(context)!;

    return settingsAsync.when(
      loading: () => _placeholderTile(context, selectedExp.code, loc),
      error: (_, _) => _placeholderTile(context, selectedExp.code, loc),
      data: (settings) {
        final enabled = settings.showOrderNumbers;

        return ListTile(
          leading: Symbols.format_list_numbered.icon(color: expColor),
          title: loc.show_build_order.capitalize().text(
            style: bodyMedium(context).withColor(expColor),
          ),
          subtitle: (enabled ? loc.enabled : loc.disabled).capitalize().text(
            style: bodySmall(context).withColor(expColor.withAlpha(175)),
          ),
          trailing: Switch(
            value: enabled,
            activeThumbColor: expColor,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withAlpha(100),
            onChanged: (v) async {
              if (v != enabled) {
                await ref
                    .read(settingsProvider.notifier)
                    .setSetting(settingsKeyShowOrderNumbers, v.toString());
              }
            },
          ),
          onTap: () async {
            final v = !enabled;
            await ref
                .read(settingsProvider.notifier)
                .setSetting(settingsKeyShowOrderNumbers, v.toString());
          },
        ).onOwnMaterial.container(
          decoration: getDefaultBoxDecoration(expColor),
        );
      },
    );
  }

  Widget _placeholderTile(
    BuildContext context,
    String expansion,
    AppLocalizations loc,
  ) {
    final color = getExpansionColor(expansion);
    return ListTile(
      leading: Symbols.format_list_numbered.icon(color: color),
      title: loc.show_build_order.capitalize().text(
        style: bodyMedium(context).withColor(color),
      ),
      subtitle: loc.loading.capitalize().text(
        style: bodySmall(context).withColor(color.withAlpha(175)),
      ),
      trailing: Switch(value: false, onChanged: null),
    ).onOwnMaterial.container(decoration: getDefaultBoxDecoration(color));
  }
}
