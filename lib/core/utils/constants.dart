// Dart Imports
import "dart:ui";

const String appName = "LTC";
const String dataDbName = "ltc_data.db";
const String dataDbPath = "assets/db/$dataDbName";
const String userDbNane = "ltc_user.db";
const String userDbPath = "assets/db/$userDbNane";

const String settingsTable = "settings";
const String settingsKeyLocale = "locale";
const String settingsValueLocaleDefault = "en";
const String settingsKeyShowOrderNumbers = "show_order_numbers";
const String settingsKeyTutorialSeen = "tutorial_seen";
const String settingsKeySelectedExpId = "selected_expansion_id";
const String settingsKeySelectedClassId = "selected_class_id";

const treeIcons = {
  "druid_balance": "spell_nature_starfall",
  "druid_feralcombat": "ability_racial_bearform",
  "druid_restoration": "spell_nature_healingtouch",
  "hunter_beastmastery": "ability_hunter_beasttaming",
  "hunter_marksmanship": "ability_marksmanship",
  "hunter_survival": "ability_hunter_swiftstrike",
  "mage_arcane": "spell_holy_magicalsentry",
  "mage_fire": "spell_fire_flamebolt",
  "mage_frost": "spell_frost_frostbolt02",
  "paladin_holy": "spell_holy_holybolt",
  "paladin_protection": "spell_holy_devotionaura",
  "paladin_retribution": "spell_holy_auraoflight",
  "priest_discipline": "spell_holy_powerwordshield",
  "priest_holy": "spell_holy_holybolt",
  "priest_shadow": "spell_shadow_shadowwordpain",
  "rogue_assassination": "ability_rogue_eviscerate",
  "rogue_combat": "ability_backstab",
  "rogue_subtlety": "ability_stealth",
  "shaman_elemental": "spell_nature_lightning",
  "shaman_enhancement": "spell_nature_lightningshield",
  "shaman_restoration": "spell_nature_magicimmunity",
  "warlock_affliction": "spell_shadow_deathcoil",
  "warlock_demonology": "spell_shadow_metamorphosis",
  "warlock_destruction": "spell_shadow_rainoffire",
  "warrior_arms": "ability_rogue_eviscerate",
  "warrior_fury": "ability_warrior_innerrage",
  "warrior_protection": "ability_warrior_defensivestance",
  "deathknight_blood": "spell_deathknight_bloodpresence",
  "deathknight_frost": "spell_deathknight_frostpresence",
  "deathknight_unholy": "spell_deathknight_unholypresence",
};

const expansions = {"vanilla", "tbc", "wotlk"};
const expansionsToIds = {"vanilla": 1, "tbc": 2, "wotlk": 3};
const idsToExpansions = {1: "vanilla", 2: "tbc", 3: "wotlk"};
const exapnsionsToMaxRows = {"vanilla": 11, "tbc": 11, "wotlk": 12};
const expansionToMaxTalentPoints = {"vanilla": 51, "tbc": 61, "wotlk": 71};
const expansionIdToMaxTalentPoints = {1: 51, 2: 61, 3: 71};
const maxColumns = 4;
final classNames = {
  "druid",
  "hunter",
  "mage",
  "paladin",
  "priest",
  "rogue",
  "shaman",
  "warlock",
  "warrior",
  "deathknight",
};
const classNamesToIds = {
  "druid": 0,
  "hunter": 1,
  "mage": 2,
  "paladin": 3,
  "priest": 4,
  "rogue": 5,
  "shaman": 6,
  "warlock": 7,
  "warrior": 8,
  "deathknight": 9,
};
const idsToClasses = {
  0: "druid",
  1: "hunter",
  2: "mage",
  3: "paladin",
  4: "priest",
  5: "rogue",
  6: "shaman",
  7: "warlock",
  8: "warrior",
  9: "deathknight",
};
final classesByExpansion = {
  "vanilla": [
    "druid",
    "hunter",
    "mage",
    "paladin",
    "priest",
    "rogue",
    "shaman",
    "warlock",
    "warrior",
  ],
  "tbc": [
    "druid",
    "hunter",
    "mage",
    "paladin",
    "priest",
    "rogue",
    "shaman",
    "warlock",
    "warrior",
  ],
  "wotlk": [
    "druid",
    "hunter",
    "mage",
    "paladin",
    "priest",
    "rogue",
    "shaman",
    "warlock",
    "warrior",
    "deathknight",
  ],
};

final classNamesWithTreeNames = {
  "druid": ["balance", "feral_combat", "restoration"],
  "hunter": ["beast_mastery", "marksmanship", "survival"],
  "mage": ["arcane", "fire", "frost"],
  "paladin": ["holy", "protection", "retribution"],
  "priest": ["discipline", "holy", "shadow"],
  "rogue": ["assassination", "combat", "subtlety"],
  "shaman": ["elemental", "enhancement", "restoration"],
  "warlock": ["affliction", "demonology", "destruction"],
  "warrior": ["arms", "fury", "protection"],
  "deathknight": ["blood", "frost", "unholy"],
};

String getTreeImagePath(String className, String treeName) {
  return "assets/images/bgs/${className}_$treeName.webp";
}

String getRngBgImagePath() {
  final classList = classNamesWithTreeNames.keys.toList();
  final className = (classList..shuffle()).first;
  final treeList = classNamesWithTreeNames[className]!;
  final treeName = (treeList..shuffle()).first;

  return getTreeImagePath(className, treeName);
}

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
};
