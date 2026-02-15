class BuildPoint {
  static const tableName = "build_points";

  final int? id;
  final int classBuildId;
  final int treeId;
  final int talentId;
  final int order;

  BuildPoint({
    this.id,
    required this.classBuildId,
    required this.treeId,
    required this.talentId,
    required this.order,
  });

  Map<String, dynamic> toDbMap() => {
    "id": id,
    "class_build_id": classBuildId,
    "tree_id": treeId,
    "talent_id": talentId,
    "order": order,
  };

  static BuildPoint fromDbRow(Map<String, Object?> map) => BuildPoint(
    id: map["id"] as int?,
    classBuildId: map["class_build_id"] as int,
    treeId: map["tree_id"] as int,
    talentId: map["talent_id"] as int,
    order: map["order"] as int,
  );

  BuildPoint copyWith({int? id, int? order}) => BuildPoint(
    id: id ?? this.id,
    classBuildId: classBuildId,
    treeId: treeId,
    talentId: talentId,
    order: order ?? this.order,
  );
}
