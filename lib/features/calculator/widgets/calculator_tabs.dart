// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/l10n/app_localizations.dart";

List<Widget> buildCalculatorTabs(
  BuildContext context,
  WidgetRef ref,
  List<TalentTree> talentTrees,
) {
  final settings = ref.watch(settingsProvider).value!;
  final classColor = settings.classColor;
  final legacyColor = settings.expColor;

  return talentTrees
      .map(
        (entry) => _iconTab(
          context,
          _getTreeIcon(entry),
          isLegacyTree(entry.id) ? legacyColor : classColor,
        ),
      )
      .toList();
}

Widget buildGlyphsTab(BuildContext context, WidgetRef ref, int classId) {
  return Semantics(
    label: AppLocalizations.of(context)!.glyphs,
    child: _iconTab(
      context,
      "assets/images/icons/inv_glyph_major${idsToClasses[classId]}.webp",
      ref.watch(settingsProvider).value!.classColor,
    ),
  );
}

Widget _iconTab(BuildContext context, String icon, Color borderColor) {
  return Tab(
    child: Container(
      width: screenWidth(context, 0.08),
      height: screenWidth(context, 0.08),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        image: DecorationImage(image: AssetImage(icon), fit: BoxFit.fill),
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2.0),
      ),
    ),
  );
}

String _getTreeIcon(TalentTree tree) {
  return "assets/images/icons/${tree.icon}.webp";
}
