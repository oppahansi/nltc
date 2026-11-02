// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";

// Project Imports
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/services/native_backup.dart";
import "package:ltc/core/utils/colors.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/core/widgets/shared.dart";
import "package:ltc/l10n/app_localizations.dart";

class ExImportSetting extends ConsumerWidget {
  const ExImportSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider).value!;
    final accent = settings.expColor;

    final width = screenWidth(context, 0.90);

    return [
          ListTile(
            dense: true,
            leading: Symbols.warning.icon(color: errorColor(context)),
            title: loc.export_import_hint.text(
              style: bodySmall(context).withColor(errorColor(context)),
            ),
            contentPadding: EdgeInsets.zero,
          ).sizedWidth(width),
          ListTile(
            leading: Symbols.save_alt.icon(color: accent),
            title: loc.export_db.text(
              style: bodyMedium(context).withColor(accent),
            ),
            subtitle: loc.save_backup_to.text(
              style: bodySmall(context).withColor(accent.withAlpha(175)),
            ),
            onTap: () async {
              try {
                final ok = await NativeBackup.exportWithPicker();
                if (!context.mounted) return;
                context.showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? loc.export_success : loc.export_canceled,
                    ),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                context.showSnackBar(
                  SnackBar(content: "${loc.export_failed}: $e".text()),
                );
              }
            },
          ).sizedWidth(width),

          ListTile(
            leading: Symbols.restore.icon(color: accent),
            title: loc.import_db.text(
              style: bodyMedium(context).withColor(accent),
            ),
            subtitle: loc.pick_a_backup_file.text(
              style: bodySmall(context).withColor(accent.withAlpha(175)),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: loc.restore_db.text(),
                  content: loc.restore_warning.text(),
                  actions: [
                    TextButton(
                      onPressed: () => ctx.pop(false),

                      child: loc.cancel.capitalize().text(),
                    ),
                    TextButton(
                      onPressed: () => ctx.pop(true),
                      child: loc.restore.capitalize().text(),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;
              try {
                final ok = await NativeBackup.importWithPicker();

                if (!context.mounted) return;
                context.showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? loc.restore_done_restart : loc.import_canceled,
                    ),
                  ),
                );
              } catch (_) {
                if (!context.mounted) return;
                context.showSnackBar(
                  SnackBar(content: loc.import_failed.text()),
                );
              }
            },
          ),
        ]
        .column(crossAxisAlignment: CrossAxisAlignment.stretch)
        .container(
          padding: const EdgeInsets.all(8.0),
          decoration: getDefaultBoxDecoration(accent),
        );
  }
}
