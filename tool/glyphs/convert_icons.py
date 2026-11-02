"""Convert the glyph icons an extract uses and the app lacks to 128x128 WebP.

Usage: <venv>/bin/python -I convert_icons.py <client Data dir> <extract.json> <assets/images/icons> <out_dir>

Reads Interface\\Icons from a 3.3.5a client's MPQs and writes only to <out_dir>. Needs Pillow.
"""

import io
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "original"))
from mpq import Client  # noqa: E402

SIZE = (128, 128)


def main():
    data_dir, extract, icons_dir, out_dir = sys.argv[1:]
    with open(extract, encoding="utf-8") as source:
        wanted = {glyph["icon"] for glyph in json.load(source)["glyphs"]}
    os.makedirs(out_dir, exist_ok=True)
    client = Client(data_dir, "enGB")
    written = 0
    for name in sorted(wanted):
        if os.path.exists(os.path.join(icons_dir, f"{name}.webp")):
            continue
        raw = client.read(f"Interface\\Icons\\{name}.blp")
        image = Image.open(io.BytesIO(raw)).convert("RGBA")
        image.resize(SIZE, Image.LANCZOS).save(os.path.join(out_dir, f"{name}.webp"), quality=85)
        written += 1
    print(f"{written} icons written to {out_dir}")


if __name__ == "__main__":
    main()
