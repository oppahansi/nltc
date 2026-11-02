# Data tools

These tools read game clients to build and check the app's talent data. They only read client files and never run anything from a client.

Run Python with `-I`, and keep downloads and work files outside the repo.

## `legacy/`: original clients (1.12.1, 2.4.3, 3.3.5a)

- `mpq.py`: read-only reader for MPQ archives and DBC tables.
- `compare_talents.py`: compares names, positions, rank counts and prerequisites with `assets/db/ltc_data.db`.
- `compare_ranks.py`: compares English rank text and calculable values. It ignores comma spacing and "sec" vs "second" wording, and some remaining differences are limits of the comparison, so review each one.

```sh
python3 -I tool/legacy/compare_talents.py <vanilla|tbc|wotlk> "<client>/Data" assets/db/ltc_data.db
python3 -I tool/legacy/compare_ranks.py <vanilla|tbc|wotlk> "<client>/Data" assets/db/ltc_data.db
```

## `forever/`: WoW Forever client (CASC and DB2)

`data/` holds the extract from pre-launch build 1.60.1.70707 and its Wowhead comparison. **This data is provisional**: re-extract from the live build before using it.

`run_pipeline.sh <install> <work_dir>` re-runs the extraction. `<work_dir>` needs WoWDBDefs at `dl/wowdbdefs` and the community listfile at `dl/listfile/community-listfile.csv`.
