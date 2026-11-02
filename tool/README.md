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

WotLK Classic (3.4.5) has no client we can read, so its extract comes from wago.tools CSVs, downloaded as `<Table>_<locale>.csv` from `https://wago.tools/db2/<Table>/csv?build=<build>&locale=<locale>`:

```sh
python3 -I tool/classic/extract_classic.py --csv <csv_dir> <build> wow_classic <dbd_dir> <out.json> <enUS|deDE>
```

`generate_sql.py` writes the extracts into `assets/db/ltc_data.db.sql`, replacing its generated block. Rebuild the DB afterwards.

```sh
python3 -I tool/classic/generate_sql.py assets/db/ltc_data.db assets/db/ltc_data.db.sql <vanilla_en.json> <vanilla_de.json> <tbc_en.json> <tbc_de.json> <wotlk_en.json> <wotlk_de.json>
```

## `forever/`: WoW Forever client (CASC and DB2)

- `extract_forever.py`: extracts regular talents and the Legacy system to one JSON per language. It reuses `classic/extract_classic.py`'s renderer, and anything it can't calculate stays visible as `[[?token]]` and is listed under `unresolved`.
- `report.py`: lists counts, the Legacy layout, icons with no file in `assets/images/icons`, unresolved tokens, text defects and en/de structure differences.
- `compare_wh.py`: compares an extract with Wowhead's talent data.
- `diff_extracts.py`: lists what changed between two extracts, Legacy included.

`data/` holds an older extract from pre-launch build 1.60.1.70707 and its Wowhead comparison, from before the `wdc.py` palette fix and without Legacy. **All Forever data is provisional**: re-extract from the live build before using it.

```sh
tool/forever/run_pipeline.sh <install> <work_dir> [out_dir]
```

This writes `forever_<build>_all_enUS.json`, `forever_<build>_all_deDE.json` and `report_<build>.txt` to `<out_dir>`, by default `<work_dir>/out`. `<work_dir>` holds WoWDBDefs at `dl/wowdbdefs` and the community listfile at `dl/listfile/community-listfile.csv`, and both are downloaded when missing.

Legacy tree IDs, the currency ID and the tree names come from the client's own UI files (`blizzard_legacysystem`, `legacyconstantsdocumentation.lua`), which are read as text and never run.

After extracting, `fetch_icons.py` converts any icons the app lacks (needs Pillow), and `generate_sql.py` writes the extracts into `assets/db/ltc_data.db.sql`, replacing its generated block. Rebuild the DB afterwards.

```sh
<venv>/bin/python -I tool/forever/fetch_icons.py "/Applications/World of Warcraft" <extract_en.json> assets/images/icons
python3 -I tool/forever/generate_sql.py assets/db/ltc_data.db assets/db/ltc_data.db.sql <extract_en.json> <extract_de.json>
```

`generate_sql.py` stops on anything it doesn't expect: a new unresolved token, a changed point cap, or a talent breaking the layout rules.

## `glyphs/`: WotLK glyphs (3.3.5a client, 3.4.5 tables)

- `extract_glyphs.py`: writes one JSON per source and language, listing each glyph's class, type, rendered text, spell, item and icon, plus slots, dropped rows, class disagreements, `[[?token]]` markers and text defects.
- `convert_icons.py`: converts icons the app lacks from a 3.3.5a client to 128x128 WebP (needs Pillow), into a folder you name.

A glyph counts only if a class 16 item for it has an Inscription recipe in `SkillLineAbility`. `GlyphProperties` alone also holds test rows and retired glyphs. 3.3.5a's client has no item names or item spells, so its items join to glyphs on the recipe's name, and `ORIGINAL_NAME_LINKS` covers the names that differ.

```sh
python3 -I tool/glyphs/extract_glyphs.py original "<client>/Data" <out_dir>
python3 -I tool/glyphs/extract_glyphs.py classic <build> <dbd_dir> <out_dir> <csv_dir> [<csv_dir> ...]
python3 -I tool/glyphs/extract_glyphs.py compare <original_enUS.json> <classic_enUS.json> assets/images/icons
<venv>/bin/python -I tool/glyphs/convert_icons.py "<client>/Data" <original_enUS.json> assets/images/icons <out_dir>
```

The Classic mode needs `extract_classic.py`'s CSVs plus `GlyphProperties`, `GlyphSlot`, `Item`, `ItemSparse`, `ItemEffect`, `SkillLineAbility`, `SpellClassOptions` and `GlobalStrings`, for enUS and deDE, downloaded the same way.
