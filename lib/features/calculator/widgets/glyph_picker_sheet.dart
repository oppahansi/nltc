// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/l10n/app_localizations.dart";

/// Lets the user fill a slot of [type], replacing the glyph it holds, if any.
Future<void> showGlyphPicker(
  BuildContext context,
  GlyphType type,
  List<Glyph> catalog, {
  Glyph? replacing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black87,
    builder: (_) =>
        _GlyphPickerSheet(type: type, catalog: catalog, replacing: replacing),
  );
}

class _GlyphPickerSheet extends ConsumerWidget {
  final GlyphType type;
  final List<Glyph> catalog;
  final Glyph? replacing;

  const _GlyphPickerSheet({
    required this.type,
    required this.catalog,
    required this.replacing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classColor = ref.watch(settingsProvider).value!.classColor;
    final chosenIds = ref.watch(buildStateProvider).value!.glyphIds;
    final loc = AppLocalizations.of(context)!;
    final glyphs = catalog.where((g) => g.type == type).toList();

    return DraggableScrollableSheet(
      expand: false,
      minChildSize: 0.35,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(gapSize(context)),
            child: Text(
              type == GlyphType.major
                  ? loc.glyphChooseMajor
                  : loc.glyphChooseMinor,
              style: titleLarge(context).withColor(classColor),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: glyphs.length,
              itemBuilder: (_, index) {
                final glyph = glyphs[index];
                final inUse = chosenIds.contains(glyph.id);
                return Opacity(
                  opacity: inUse ? 0.45 : 1,
                  child: ListTile(
                    enabled: !inUse,
                    onTap: () {
                      ref
                          .read(buildStateProvider.notifier)
                          .chooseGlyph(
                            glyph,
                            catalog,
                            replacing: replacing?.id,
                          );
                      Navigator.of(context).pop();
                    },
                    leading: Image.asset(
                      "assets/images/icons/${glyph.icon}.webp",
                      width: 40,
                      height: 40,
                    ),
                    title: Text(
                      glyph.name,
                      style: bodyMedium(context).withColor(classColor),
                    ),
                    subtitle: Text(
                      inUse
                          ? "${loc.glyphInUse}\n${glyph.description}"
                          : glyph.description,
                      style: bodySmall(context).withColor(Colors.white70),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
