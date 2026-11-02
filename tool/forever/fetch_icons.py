"""Convert the icons an extract needs and the app lacks to WebP. Read-only on the install.

Usage: <venv>/bin/python -I fetch_icons.py <install> <extract.json> <assets/images/icons>

Needs Pillow. Existing files are left alone.
"""

import io
import json
import os
import struct
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import casc  # noqa: E402

SIZE = (128, 128)


def main():
    install, extract, out_dir = sys.argv[1:]
    data = json.load(open(extract, encoding="utf-8"))
    client = casc.Casc(install)

    def load(fdid):
        raw = client.read_fdid(fdid, "enUS")
        if raw[:4] == b"BLP2" and raw[8] == 3:
            # Pillow doesn't read this encoding, which is plain BGRA.
            width, height = struct.unpack_from("<II", raw, 12)
            offset = struct.unpack_from("<I", raw, 20)[0]
            pixels = raw[offset : offset + width * height * 4]
            return Image.frombytes("RGBA", (width, height), pixels, "raw", "BGRA")
        return Image.open(io.BytesIO(raw)).convert("RGBA")

    wanted = {}
    for cdata in data["classes"].values():
        for tree in cdata["trees"]:
            wanted[tree["icon"]] = tree["icon_fdid"]
            for talent in tree["talents"]:
                wanted[talent["icon"]] = talent["icon_fdid"]
    for tree in data["legacy"]["trees"]:
        for node in tree["nodes"]:
            if not node["placeholder"]:
                wanted[node["icon"]] = node["icon_fdid"]

    written = 0
    for name, fdid in sorted(wanted.items()):
        path = os.path.join(out_dir, f"{name}.webp")
        if not os.path.exists(path):
            load(fdid).resize(SIZE, Image.LANCZOS).save(path, quality=85)
            written += 1

    for tree in data["legacy"]["trees"]:
        path = os.path.join(out_dir, f"legacy_{tree['name'].lower()}.webp")
        if not os.path.exists(path):
            r = tree["atlas_rect"]
            atlas = load(tree["atlas_file_fdid"])
            atlas.crop((r["left"], r["top"], r["right"], r["bottom"])).resize(SIZE, Image.LANCZOS).save(path, quality=85)
            written += 1
    print(f"{written} icons written")


if __name__ == "__main__":
    main()
