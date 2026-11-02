const String dataDbName = "ltc_data.db";
const String dataDbPath = "assets/db/$dataDbName";
const String userDbName = "ltc_user.db";
const String userDbPath = "assets/db/$userDbName";

/// Bump when the bundled data changes, and match `PRAGMA user_version` at the
/// top of the data DB's SQL. Installs on another version get the new file.
const int dataDbVersion = 4;

/// Bump when the user DB's schema changes: add the step to [DbMigrations],
/// update the bundled SQL, and match its `PRAGMA user_version`.
const int userDbVersion = 2;
