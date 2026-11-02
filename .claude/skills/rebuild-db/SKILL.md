---
name: rebuild-db
description: Rebuild the bundled SQLite databases in assets/db/ from their .db.sql source files. Use after editing ltc_data.db.sql or ltc_user.db.sql.
disable-model-invocation: true
---

Rebuild the bundled databases from SQL. `$ARGUMENTS` names which one: `ltc_data`, `ltc_user`, or empty for both.

For each database, run from the repo root:

```sh
name=ltc_data  # or ltc_user
tmp="$(mktemp -d)/$name.db"
sqlite3 -bail "$tmp" < "assets/db/$name.db.sql"
sqlite3 "$tmp" "PRAGMA integrity_check; PRAGMA foreign_key_check;"
```

Before replacing anything, check that:

1. The `sqlite3` import exited 0.
2. `integrity_check` printed `ok` and `foreign_key_check` printed nothing.
3. The new DB has the expected tables. Compare with `sqlite3 "$tmp" ".tables"` and `sqlite3 "assets/db/$name.db" ".tables"`, and explain any difference that the SQL edit doesn't account for.

If any check fails, stop and report the output, leaving `assets/db/$name.db` untouched. Otherwise run `mv "$tmp" "assets/db/$name.db"`.

Report row-count changes for the tables touched by the SQL edit. If the data DB's content changed, bump `dataDbVersion` in `lib/core/db/db_constants.dart` and `PRAGMA user_version` in the SQL before the final rebuild, or existing installs won't get it. A schema change to the user DB also needs a step in `lib/core/db/migrations.dart`.
