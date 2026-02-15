class Realm {
  final int id;
  final String name;
  final String slug;
  Realm({required this.id, required this.name, required this.slug});
}

class RemoteClassBuilds {
  final String className;
  final List<RemoteClassBuild> builds;
  RemoteClassBuilds({required this.className, required this.builds});
}

class RemoteClassBuild {
  final bool isActive;
  final Map<String, Map<String, int>> talentTreeTalents;

  RemoteClassBuild(this.isActive, this.talentTreeTalents);
}

class BattleNetToken {
  final String accessToken;
  final int expiresIn;
  final DateTime obtainedAt;
  BattleNetToken({
    required this.accessToken,
    required this.expiresIn,
    required this.obtainedAt,
  });
  DateTime get expiry => obtainedAt.add(Duration(seconds: expiresIn));
  bool get isExpired => DateTime.now().isAfter(expiry);
}
