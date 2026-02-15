// Flutter Imports
import "package:flutter/material.dart";

// Project Imports
import "package:ltc/core/utils/constants.dart";

Map<String, String> classColors = {
  "druid": "#FF7D0A",
  "hunter": "#ABD473",
  "mage": "#69CCF0",
  "paladin": "#F58CBA",
  "priest": "#FFFFFF",
  "rogue": "#FFF569",
  "shaman": "#0070DE",
  "warlock": "#9482C9",
  "warrior": "#C79C6E",
  "deathknight": "#C41E3A",
  "druide": "#FF7D0A",
  "jäger": "#ABD473",
  "magier": "#69CCF0",
  "priester": "#FFFFFF",
  "schurke": "#FFF569",
  "schamane": "#0070DE",
  "hexenmeister": "#9482C9",
  "krieger": "#C79C6E",
  "todesritter": "#C41E3A",
};

Color getExpansionColor(String expansion) {
  switch (expansion) {
    case 'tbc':
      return expColors['tbc']!.first;
    case 'wotlk':
      return expColors['wotlk']![1];
    default:
      return expColors['vanilla']!.first;
  }
}

Map<String, List<Color>> getWoWExpansionColors() {
  return {
    'vanilla': [
      Color(0xFFFFD700), // Gold for classic WoW logo
      Color(0xFF1A2526), // Dark teal-blue for starry background
      Color(0xFF4A3727), // Earthy brown for Azeroth landscapes
      Color(0xFF3A5F3A), // Green for natural zones
    ],
    'tbc': [
      Color(0xFF1B9C34), // Fel green for Outland and Dark Portal
      Color(0xFF2E1B4F), // Deep purple for demonic/void themes
      Color(0xFFFF4500), // Orange-red for Hellfire Peninsula
      Color(0xFF0A0A0A), // Near-black for dark backgrounds
    ],
    'wotlk': [
      Color(0xFF00B7EB), // Icy blue for Northrend and Lich King
      Color(0xFF4682B4), // Steel blue for icy motifs
      Color(0xFF2F2F2F), // Dark gray for Scourge themes
      Color(0xFF6A0DAD), // Purple for necromantic/Dalaran elements
    ],
  };
}

Color primaryColor(BuildContext context) =>
    Theme.of(context).colorScheme.primary;

Color onPrimaryColor(BuildContext context) =>
    Theme.of(context).colorScheme.onPrimary;

Color primaryContainerColor(BuildContext context) =>
    Theme.of(context).colorScheme.primaryContainer;

Color onPrimaryContainerColor(BuildContext context) =>
    Theme.of(context).colorScheme.onPrimaryContainer;

Color secondaryColor(BuildContext context) =>
    Theme.of(context).colorScheme.secondary;

Color onSecondaryColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSecondary;

Color secondaryContainerColor(BuildContext context) =>
    Theme.of(context).colorScheme.secondaryContainer;

Color onSecondaryContainerColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSecondaryContainer;

Color tertiaryColor(BuildContext context) =>
    Theme.of(context).colorScheme.tertiary;

Color onTertiaryColor(BuildContext context) =>
    Theme.of(context).colorScheme.onTertiary;

Color tertiaryContainerColor(BuildContext context) =>
    Theme.of(context).colorScheme.tertiaryContainer;

Color onTertiaryContainerColor(BuildContext context) =>
    Theme.of(context).colorScheme.onTertiaryContainer;

Color errorColor(BuildContext context) => Theme.of(context).colorScheme.error;

Color onErrorColor(BuildContext context) =>
    Theme.of(context).colorScheme.onError;

Color errorContainerColor(BuildContext context) =>
    Theme.of(context).colorScheme.errorContainer;

Color onErrorContainerColor(BuildContext context) =>
    Theme.of(context).colorScheme.onErrorContainer;

Color backgroundColor(BuildContext context) =>
    Theme.of(context).colorScheme.surface;

Color onBackgroundColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

Color surfaceColor(BuildContext context) =>
    Theme.of(context).colorScheme.surface;

Color surfaceTintColor(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceTint;

Color surfaceContainerLowColor(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerLow;

Color surfaceContainerColor(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainer;

Color onSurfaceColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

Color surfaceDimColor(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceDim;

Color surfaceContainerHighest(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHighest;

Color onSurfaceVariantColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

Color outlineColor(BuildContext context) =>
    Theme.of(context).colorScheme.outline;

Color outlineVariantColor(BuildContext context) =>
    Theme.of(context).colorScheme.outlineVariant;

Color shadowColor(BuildContext context) => Theme.of(context).colorScheme.shadow;

Color scrimColor(BuildContext context) => Theme.of(context).colorScheme.scrim;

Color inverseSurfaceColor(BuildContext context) =>
    Theme.of(context).colorScheme.inverseSurface;

Color onInverseSurfaceColor(BuildContext context) =>
    Theme.of(context).colorScheme.onInverseSurface;

Color inversePrimaryColor(BuildContext context) =>
    Theme.of(context).colorScheme.inversePrimary;

Color getColorForRating(int quality) {
  if (quality <= 5) {
    return Color.lerp(Colors.red, Colors.yellow, quality / 5)!;
  } else {
    return Color.lerp(Colors.yellow, Colors.green, (quality - 5) / 5)!;
  }
}

Color weightDiffColor(double weightDiff) {
  if (weightDiff < 0) {
    return Colors.green;
  } else if (weightDiff == 0) {
    return Colors.grey;
  } else {
    return Colors.red;
  }
}
