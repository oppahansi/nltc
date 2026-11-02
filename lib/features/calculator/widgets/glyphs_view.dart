// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/features/calculator/providers/calculator_providers.dart";
import "package:ltc/features/calculator/widgets/glyph_picker_sheet.dart";
import "package:ltc/l10n/app_localizations.dart";

/// A WotLK build's glyph slots, with room below for the undo button.
class GlyphsView extends ConsumerWidget {
  const GlyphsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classBuild = ref.watch(buildStateProvider).value!;
    final catalog = ref.watch(
      classGlyphsProvider(
        expansionId: classBuild.expansionId,
        classId: classBuild.classId,
      ),
    );
    final expColor = ref.watch(settingsProvider).value!.expColor;
    final loc = AppLocalizations.of(context)!;

    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("$e")),
      data: (glyphs) => ListView(
        padding: EdgeInsets.fromLTRB(
          gapSize(context),
          gapSize(context),
          gapSize(context),
          screenWidth(context, 0.3),
        ),
        children: [
          _section(
            context,
            loc.glyphsMajor,
            GlyphType.major,
            glyphs,
            classBuild.glyphIds,
            expColor,
          ),
          SizedBox(height: gapSize(context)),
          _section(
            context,
            loc.glyphsMinor,
            GlyphType.minor,
            glyphs,
            classBuild.glyphIds,
            expColor,
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    GlyphType type,
    List<Glyph> catalog,
    List<int> chosenIds,
    Color color,
  ) {
    final byId = {for (final glyph in catalog) glyph.id: glyph};
    final chosen = [
      for (final id in chosenIds)
        if (byId[id]?.type == type) byId[id]!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: gapSize(context) / 2),
          child: Text(title, style: titleLarge(context).withColor(color)),
        ),
        for (var i = 0; i < glyphSlotsPerType; i++)
          _GlyphSlot(
            type: type,
            glyph: i < chosen.length ? chosen[i] : null,
            catalog: catalog,
          ),
      ],
    );
  }
}

class _GlyphSlot extends ConsumerWidget {
  final GlyphType type;
  final Glyph? glyph;
  final List<Glyph> catalog;

  const _GlyphSlot({
    required this.type,
    required this.glyph,
    required this.catalog,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value!;
    final classColor = settings.classColor;
    final loc = AppLocalizations.of(context)!;
    final glyph = this.glyph;
    final classCode =
        idsToClasses[ref.watch(buildStateProvider).value!.classId];

    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: glyph == null ? Colors.white24 : classColor),
      ),
      child: ListTile(
        onTap: () => showGlyphPicker(context, type, catalog, replacing: glyph),
        leading: Opacity(
          opacity: glyph == null ? 0.35 : 1,
          child: Image.asset(
            "assets/images/icons/${glyph?.icon ?? "inv_glyph_${type.name}$classCode"}.webp",
            width: 40,
            height: 40,
          ),
        ),
        title: Text(
          glyph?.name ?? loc.glyphSlotEmpty,
          style: bodyMedium(context)
              .withColor(glyph == null ? Colors.white54 : classColor),
        ),
        subtitle: Text(
          glyph?.description ?? loc.glyphSlotHint,
          style: bodySmall(context).withColor(Colors.white70),
        ),
        trailing: glyph == null
            ? null
            : IconButton(
                tooltip: loc.glyphRemove,
                icon: const Icon(Symbols.close, color: Colors.white70),
                onPressed: () =>
                    ref.read(buildStateProvider.notifier).removeGlyph(glyph.id),
              ),
      ),
    );
  }
}
