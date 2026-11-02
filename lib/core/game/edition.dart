/// Which line of the game an expansion belongs to.
enum Edition {
  /// The original clients from back then.
  original,

  /// The re-releases played today.
  classic,

  /// World of Warcraft: Forever, which isn't split into expansions.
  forever;

  static Edition fromCode(String code) =>
      values.firstWhere((e) => e.name == code, orElse: () => original);
}
