// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";

// Project Imports
import "package:ltc/core/providers/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/core/widgets/shared.dart";
import "package:ltc/features/builds/providers/builds_providers.dart";
import "package:ltc/l10n/app_localizations.dart";

class RegionRealmSelector extends ConsumerWidget {
  const RegionRealmSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value!;
    final region = ref.watch(selectedRegionProvider);
    final realmsAsync = ref.watch(realmsProvider(region));
    final selectedRealm = ref.watch(selectedRealmProvider);
    final loc = AppLocalizations.of(context)!;

    final expColor = settings.expColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;

        final inputDeco = InputDecoration(
          labelText: loc.region.capitalize(),
          labelStyle: bodyMedium(context).withColor(expColor),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: expColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: expColor),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        );

        return realmsAsync.when(
          data: (realms) {
            final regionField = DropdownButtonFormField<String>(
              initialValue: region,
              style: bodyMedium(context).withColor(expColor),
              decoration: inputDeco,
              dropdownColor: Colors.black,
              items: const [
                DropdownMenuItem(value: "us", child: Text("United States")),
                DropdownMenuItem(value: "eu", child: Text("Europe")),
                DropdownMenuItem(value: "kr", child: Text("Korea")),
                DropdownMenuItem(value: "tw", child: Text("Taiwan")),
              ],
              onChanged: (v) {
                if (v == null) return;
                ref.read(selectedRegionProvider.notifier).setRegion(v);
                ref.read(selectedRealmProvider.notifier).clear();
              },
            );

            final realmField = DropdownButtonFormField<String>(
              initialValue: selectedRealm,
              style: bodyMedium(context).withColor(expColor),
              decoration: InputDecoration(
                labelText: loc.server.capitalize(),
                labelStyle: bodyMedium(context).withColor(expColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: expColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: expColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              dropdownColor: Colors.black,
              items: realms
                  .map(
                    (r) => DropdownMenuItem<String>(
                      value: r.slug,
                      child: r.name.text(
                        overflow: TextOverflow.ellipsis,
                        style: bodyMedium(context).withColor(expColor),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                ref.read(selectedRealmProvider.notifier).setRealm(v);
              },
              validator: (v) =>
                  (v == null || v.isEmpty) ? loc.required.capitalize() : null,
            );

            return [
              if (isNarrow) ...[
                regionField,
                gapSizeSmall(context).gapColumn,
                realmField,
              ] else
                [
                  Expanded(child: regionField),
                  gapSize(context).gapColumn,
                  Expanded(child: realmField),
                ].row(),
              const SizedBox(height: 12),
            ].columnCrossStart();
          },
          loading: () => [
            CircularProgressIndicator(color: expColor),
            gapSize(context).gapRow,
            "${loc.loading.capitalize()}...".text(
              style: bodyMedium(context).withColor(expColor),
            ),
          ].row(mainAxisSize: MainAxisSize.min).center(),
          error: (e, st) =>
              [
                    loc.failed_to_load_realms.text(
                      style: bodyMedium(context).withColor(Colors.redAccent),
                    ),
                    gapSize(context).gapColumn,
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(realmsProvider(region));
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: expColor),
                        foregroundColor: expColor,
                      ),
                      icon: Symbols.refresh.icon(size: gapSize(context)),
                      label: loc.retry.capitalize().text(),
                    ).sizedHeight(gapSize(context)),
                  ]
                  .columnCrossStart()
                  .container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: getDefaultBoxDecoration(Colors.redAccent),
                  )
                  .paddingAll(gapSizeSmall(context)),
        );
      },
    ).sizedWidth(double.infinity);
  }
}
