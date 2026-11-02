# Data tools

These tools read game clients to build and check the app's talent data. They only read client files and never run anything from a client.

Run Python with `-I`, and keep downloads and work files outside the repo.

## `original/`: original clients (1.12.1, 2.4.3, 3.3.5a)

- `mpq.py`: read-only reader for MPQ archives and DBC tables.
- `compare_talents.py`: compares names, positions, rank counts and prerequisites with `assets/db/ltc_data.db`.
- `compare_ranks.py`: compares English rank text and calculable values. It ignores comma spacing and "sec" vs "second" wording, and some remaining differences are limits of the comparison, so review each one.

```sh
python3 -I tool/original/compare_talents.py <vanilla|tbc|wotlk> "<client>/Data" assets/db/ltc_data.db
python3 -I tool/original/compare_ranks.py <vanilla|tbc|wotlk> "<client>/Data" assets/db/ltc_data.db
```

## `classic/`: Classic Era and TBC Anniversary clients

- `extract_classic.py`: extracts talents and rendered descriptions from a client to JSON, for a chosen language.
- `compare_original.py`: lists how an extract differs from the Original edition in the app's database.

```sh
python3 -I tool/classic/extract_classic.py "/Applications/World of Warcraft" <wow_classic_era|wow_anniversary> <dbd_dir> <listfile.csv> <out.json> <enUS|deDE>
python3 -I tool/classic/compare_original.py <out.json> assets/db/ltc_data.db
```

`<dbd_dir>` is WoWDBDefs' `definitions` folder, and `<listfile.csv>` is the community listfile.

## `forever/`: WoW Forever client (CASC and DB2)

`data/` holds the extract from pre-launch build 1.60.1.70707 and its Wowhead comparison. **This data is provisional**: re-extract from the live build before using it.

`run_pipeline.sh <install> <work_dir>` re-runs the extraction. `<work_dir>` needs WoWDBDefs at `dl/wowdbdefs` and the community listfile at `dl/listfile/community-listfile.csv`.
