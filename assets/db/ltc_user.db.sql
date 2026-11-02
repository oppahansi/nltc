PRAGMA user_version = 1;
BEGIN TRANSACTION;
DROP TABLE IF EXISTS "build_points";
CREATE TABLE build_points (
  id INTEGER PRIMARY KEY,
  class_build_id INTEGER NOT NULL,
  tree_id INTEGER NOT NULL,
  talent_id INTEGER NOT NULL,
  "order" INTEGER NOT NULL,
  FOREIGN KEY (class_build_id) REFERENCES class_builds(id) ON DELETE CASCADE
);
DROP TABLE IF EXISTS "class_builds";
CREATE TABLE class_builds (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  expansion_id INTEGER NOT NULL,
  expansion_code TEXT NOT NULL,
  class_id INTEGER NOT NULL,
  class_name TEXT NOT NULL,
  talent_ranks TEXT NOT NULL,   -- JSON: {"buildPointId": rank, ...}
  talents_build_sequence TEXT NOT NULL   -- JSON: [buildPointId, ...]
);
DROP TABLE IF EXISTS "settings";
CREATE TABLE settings (
  "key" TEXT PRIMARY KEY,
  "value" TEXT NOT NULL
);
DROP INDEX IF EXISTS "idx_build_points_class_build_id";
CREATE INDEX idx_build_points_class_build_id ON build_points(class_build_id);
DROP INDEX IF EXISTS "idx_build_points_order";
CREATE INDEX idx_build_points_order ON build_points("order");
DROP INDEX IF EXISTS "idx_build_points_talent_id";
CREATE INDEX idx_build_points_talent_id ON build_points(talent_id);
DROP INDEX IF EXISTS "idx_build_points_tree_id";
CREATE INDEX idx_build_points_tree_id ON build_points(tree_id);
DROP INDEX IF EXISTS "idx_class_builds_class_id";
CREATE INDEX idx_class_builds_class_id ON class_builds(class_id);
DROP INDEX IF EXISTS "idx_class_builds_expansion_id";
CREATE INDEX idx_class_builds_expansion_id ON class_builds(expansion_id);
COMMIT;
