// Dart Imports
import "dart:ui";

// Project Imports
import "package:ltc/core/game/game_catalog.dart";

Map<String, List<Color>> expColors = {
  "vanilla": [
    Color(0xFFFFD700), // Gold for classic WoW logo
    Color(0xFF1A2526), // Dark teal-blue for starry background
    Color(0xFF4A3727), // Earthy brown for Azeroth landscapes
    Color(0xFF3A5F3A), // Green for natural zones
  ],
  "tbc": [
    Color(0xFF1B9C34), // Fel green for Outland and Dark Portal
    Color(0xFF2E1B4F), // Deep purple for demonic/void themes
    Color(0xFFFF4500), // Orange-red for Hellfire Peninsula
    Color(0xFF0A0A0A), // Near-black for dark backgrounds
  ],
  "wotlk": [
    Color(0xFF00B7EB), // Icy blue for Northrend and Lich King
    Color(0xFF4682B4), // Steel blue for icy motifs
    Color(0xFF2F2F2F), // Dark gray for Scourge themes
    Color(0xFF6A0DAD), // Purple for necromantic/Dalaran elements
  ],
  "forever": [
    Color(0xFF2DD4BF), // Teal from the logo, clearly greener than WotLK's blues
  ],
};

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
};

Color getExpansionColor(String expansionCode) {
  switch (eraOf(expansionCode)) {
    case 'tbc':
      return expColors['tbc']!.first;
    case 'wotlk':
      return expColors['wotlk']![1];
    case 'forever':
      return expColors['forever']!.first;
    default:
      return expColors['vanilla']!.first;
  }
}
