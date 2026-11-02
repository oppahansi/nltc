"""Write the WotLK glyphs into ltc_data.db.sql, from extract_glyphs.py's output.

Usage: python3 -I generate_sql.py <ltc_data.db.sql> <original_en.json> <original_de.json> <classic_en.json> <classic_de.json>

A glyph's id is its GlyphProperties id, which saved builds and share codes refer
to, so it must not change. Reruns replace the block between the markers, and
anything unexpected stops generation.
"""

import json
import re
import sys

BEGIN, END = "-- BEGIN GENERATED GLYPH DATA", "-- END GENERATED GLYPH DATA"
ORIGINAL_WOTLK, CLASSIC_WOTLK = 3, 6
TYPES = {"major", "minor"}
# Client text that can't be rendered without a character or a formula's context.
# Innervate's pronoun depends on the character. Shocking's formula divides the
# -500 ms of the spell's first effect, and Original words the same change as
# "to 1 sec" from a 1.5 sec cooldown, so it's half a second.
FIXES = {
    "en": {"[[?$ghis:her;]]": "their", "[[?${$m2/-1000}.1]]": "0.5"},
    "de": {"[[?${$m2/-1000}.1]]": "0,5"},
}


def fail(message):
    raise SystemExit(message)


def load(path):
    return {g["id"]: g for g in json.load(open(path, encoding="utf-8"))["glyphs"]}


def clean(text, language, glyph_id):
    for token, value in FIXES[language].items():
        text = text.replace(token, value)
    if "$" in text or "[[" in text:
        fail(f"glyph {glyph_id} ({language}) has an unresolved token: {text}")
    return text


def quote(text):
    return "'" + text.replace("'", "''") + "'"


def rows(expansion, en_path, de_path):
    en, de = load(en_path), load(de_path)
    if en.keys() != de.keys():
        fail(f"expansion {expansion}: English and German have different glyphs")
    out = []
    for glyph_id in sorted(en):
        glyph = en[glyph_id]
        if glyph["type"] not in TYPES:
            fail(f"glyph {glyph_id} has unknown type {glyph['type']}")
        if (de[glyph_id]["class_id"], de[glyph_id]["type"]) != (glyph["class_id"], glyph["type"]):
            fail(f"glyph {glyph_id}: English and German disagree")
        expected_icon = f"inv_glyph_{glyph['type']}{glyph['class']}"
        if glyph["icon"] != expected_icon:
            fail(f"glyph {glyph_id} has unexpected icon {glyph['icon']}")
        out.append(
            f"INSERT INTO glyphs VALUES ({expansion},{glyph_id},{glyph['class_id']},"
            f"{quote(glyph['type'])},{quote(glyph['icon'])});"
        )
        for language, source in (("en", en), ("de", de)):
            name = source[glyph_id]["name"]
            description = clean(source[glyph_id]["description"], language, glyph_id)
            if not name or not description:
                fail(f"glyph {glyph_id} ({language}) is missing text")
            out.append(
                f"INSERT INTO glyph_texts VALUES ({expansion},{glyph_id},{quote(language)},"
                f"{quote(name)},{quote(description)});"
            )
    return out


def main():
    if len(sys.argv) != 6:
        fail(__doc__)
    sql_path, original_en, original_de, classic_en, classic_de = sys.argv[1:]
    block = [
        BEGIN,
        "DROP TABLE IF EXISTS glyph_texts;",
        "DROP TABLE IF EXISTS glyphs;",
        "CREATE TABLE glyphs (expansion INTEGER NOT NULL, id INTEGER NOT NULL, classId INTEGER NOT NULL, "
        "type TEXT NOT NULL, icon TEXT NOT NULL, PRIMARY KEY (expansion, id));",
        "CREATE TABLE glyph_texts (expansion INTEGER NOT NULL, glyphId INTEGER NOT NULL, languageCode TEXT NOT NULL, "
        "name TEXT NOT NULL, description TEXT NOT NULL, PRIMARY KEY (expansion, glyphId, languageCode), "
        "FOREIGN KEY (expansion, glyphId) REFERENCES glyphs (expansion, id));",
        *rows(ORIGINAL_WOTLK, original_en, original_de),
        *rows(CLASSIC_WOTLK, classic_en, classic_de),
        END,
    ]

    text = open(sql_path, encoding="utf-8").read()
    text = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?", "", text, flags=re.S)
    if not text.rstrip().endswith("COMMIT;"):
        fail("expected the SQL file to end with COMMIT;")
    head = text.rstrip()[: -len("COMMIT;")]
    open(sql_path, "w", encoding="utf-8").write(head + "\n".join(block) + "\nCOMMIT;\n")
    print(f"wrote {len(block)} lines")


if __name__ == "__main__":
    main()
