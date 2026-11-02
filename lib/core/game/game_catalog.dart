const String defaultLanguageCode = "en";

const expansionsToIds = {
  "vanilla": 1,
  "tbc": 2,
  "wotlk": 3,
  "classic_vanilla": 4,
  "classic_tbc": 5,
  "classic_wotlk": 6,
  "forever": 7,
};

const _classicPrefix = "classic_";
const _foreverCode = "forever";
const _maxTalentPointsByEra = {
  "vanilla": 51,
  "tbc": 61,
  "wotlk": 71,
  _foreverCode: 51,
};
const _eraLabels = {
  "vanilla": "Vanilla",
  "tbc": "TBC",
  "wotlk": "WotLK",
  _foreverCode: "Forever",
};

/// The game era of an expansion code: `classic_tbc` and `tbc` are both `tbc`.
String eraOf(String expansionCode) => expansionCode.startsWith(_classicPrefix)
    ? expansionCode.substring(_classicPrefix.length)
    : expansionCode;

/// 0 for an expansion this version doesn't know, such as from a newer backup.
int maxTalentPoints(String expansionCode) =>
    _maxTalentPointsByEra[eraOf(expansionCode)] ?? 0;

String eraLabel(String era) => _eraLabels[era] ?? era;

/// How saved builds name their expansion, for example `Classic TBC` or `Forever`.
String expansionLabel(String expansionCode) {
  if (expansionCode == _foreverCode) return eraLabel(_foreverCode);
  final edition = expansionCode.startsWith(_classicPrefix)
      ? "Classic"
      : "Original";
  return "$edition ${eraLabel(eraOf(expansionCode))}";
}

const maxColumns = 4;
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

/// Eras with a Wowhead talent calculator, and their part of its URLs.
const wowheadEraSlugs = {"tbc": "tbc", "wotlk": "wotlk"};
