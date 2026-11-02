"""Minimal WDC3/4/5/6 DB2 reader plus WoWDBDefs (.dbd) parser. Stdlib only.

Encrypted sections (tact_key_hash != 0) are SKIPPED and reported, never decrypted.
"""
import os, re, struct


def fit_width(value, size):
    """An integer at its column's declared width, such as "u8" or "16". Palettes store
    32 bits, and what lies above a narrower column's width is garbage."""
    digits = re.sub(r"\D", "", size or "")
    if not digits:
        return value
    bits = int(digits)
    value &= (1 << bits) - 1
    if not size.startswith("u") and value >> (bits - 1):
        value -= 1 << bits
    return value


def parse_dbd(path):
    """Returns (columns: name->(type,fk), layouts: list of dict(layouts, builds, fields))."""
    cols = {}
    defs = []
    cur = None
    mode = None
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.rstrip("\n")
        if line.startswith("COLUMNS"):
            mode = "cols"
            continue
        if not line.strip():
            cur = None
            mode = None if mode != "cols" else None
            continue
        if mode == "cols":
            m = re.match(r"(\w+)(?:<([^>]+)>)?\s+(\w+\??)", line)
            if m:
                cols[m.group(3).rstrip("?")] = (m.group(1), m.group(2))
            continue
        if line.startswith("LAYOUT") or line.startswith("BUILD") or line.startswith("COMMENT"):
            if cur is None:
                cur = {"layouts": [], "builds": [], "fields": []}
                defs.append(cur)
            if line.startswith("LAYOUT"):
                cur["layouts"] += [x.strip().upper() for x in line[6:].split(",")]
            elif line.startswith("BUILD"):
                cur["builds"] += [x.strip() for x in line[5:].split(",")]
            continue
        if cur is not None:
            m = re.match(r"(?:\$([^$]*)\$)?(\w+)(?:<([^>]+)>)?(?:\[(\d+)\])?", line)
            ann = (m.group(1) or "").split(",") if m.group(1) else []
            cur["fields"].append({
                "name": m.group(2), "ann": ann, "size": m.group(3),
                "arr": int(m.group(4)) if m.group(4) else 1})
    return cols, defs


class WDC:
    def __init__(self, data, cols, defs, build=None, name=""):
        self.name = name
        d = data
        self.magic = d[:4]
        assert self.magic in (b"WDC3", b"WDC4", b"WDC5", b"WDC6"), self.magic
        p = 4
        self.version = None
        if self.magic in (b"WDC5", b"WDC6"):
            self.version = struct.unpack("<I", d[4:8])[0]
            self.schema = d[8:136].split(b"\0")[0].decode(errors="replace")
            p = 136
        (self.record_count, self.field_count, self.record_size, self.string_size,
         self.table_hash, self.layout_hash, self.min_id, self.max_id, self.locale,
         self.flags, self.id_index, self.total_fields, self.bitpacked_off,
         self.lookup_cols, self.fsi_size, self.common_size, self.pallet_size,
         self.section_count) = struct.unpack("<IIIIIIIIIHHIIIIIII", d[p:p + 68])
        p += 68
        secs = []
        for i in range(self.section_count):
            s = struct.unpack("<QIIIIIIII", d[p:p + 40])
            p += 40
            secs.append(dict(zip(["key", "off", "n", "str", "end", "idsz", "relsz", "omc", "copy"], s)))
        self.sections = secs
        fields = []
        for i in range(self.field_count):
            sz, pos = struct.unpack("<hH", d[p:p + 4])
            fields.append((sz, pos))
            p += 4
        self.fsi = []
        for i in range(self.fsi_size // 24):
            off, sz, addl, comp, v1, v2, v3 = struct.unpack("<HHIIIII", d[p:p + 24])
            self.fsi.append(dict(off=off, bits=sz, addl=addl, comp=comp, v1=v1, v2=v2, v3=v3))
            p += 24
        pal_start = p
        self.pal = {}
        q = pal_start
        for i, f in enumerate(self.fsi):
            if f["comp"] in (3, 4):
                self.pal[i] = d[q:q + f["addl"]]
                q += f["addl"]
        p += self.pallet_size
        self.common = {}
        q = p
        for i, f in enumerate(self.fsi):
            if f["comp"] == 2:
                m = {}
                for j in range(f["addl"] // 8):
                    k, v = struct.unpack("<II", d[q:q + 8])
                    m[k] = v
                    q += 8
                self.common[i] = m
        p += self.common_size
        # resolve dbd layout
        lh = "%08X" % self.layout_hash
        dd = None
        for x in defs:
            if lh in x["layouts"] and (build is None or build in x["builds"] or not x["builds"]):
                dd = x
                break
        if dd is None:
            for x in defs:
                if lh in x["layouts"]:
                    dd = x
                    break
        if dd is None:
            for x in defs:
                if build in x["builds"]:
                    dd = x
                    break
        if dd is None:
            raise ValueError("%s: no dbd for layout %s" % (name, lh))
        self.dd = dd
        self.columns = cols
        # field map: inline fields only
        inline = [f for f in dd["fields"] if "noninline" not in f["ann"]]
        self.inline = inline
        self.rows = {}
        self.encrypted_sections = 0
        self.encrypted_records = 0
        strtab_base = 0
        rec_base = 0
        total_rec = sum(s["n"] for s in secs) * self.record_size
        # each section's records and strings are positioned in file; offset-map tables unsupported
        ns_all = []
        for s in secs:
            if s["key"] != 0:
                self.encrypted_sections += 1
                self.encrypted_records += s["n"]
            ns_all.append(s)
        # global string table concatenation
        strs = bytearray()
        offsets = []
        for s in secs:
            offsets.append(len(strs))
            if self.flags & 1:
                continue
            strs += d[s["off"] + s["n"] * self.record_size:s["off"] + s["n"] * self.record_size + s["str"]]
        self.strs = bytes(strs)
        gidx = 0
        for si, s in enumerate(secs):
            if s["key"] != 0 or s["n"] == 0 or s["off"] == 0:
                gidx += s["n"]
                continue
            if self.flags & 1:
                self._read_sparse(d, s, si)
                gidx += s["n"]
                continue
            base = s["off"]
            rstart = base
            sstart = base + s["n"] * self.record_size
            p2 = sstart + s["str"]
            ids = None
            if s["idsz"]:
                ids = struct.unpack("<%dI" % (s["idsz"] // 4), d[p2:p2 + s["idsz"]])
            p2 += s["idsz"]
            copies = struct.unpack("<%dI" % (s["copy"] * 2), d[p2:p2 + 8 * s["copy"]]) if s["copy"] else ()
            p2 += 8 * s["copy"]
            p2 += s["omc"] * 6  # offset map entries (unused here)
            rel = {}
            if s["relsz"]:
                cnt = struct.unpack("<I", d[p2:p2 + 4])[0]
                q = p2 + 12
                for i in range(cnt):
                    fid, ri = struct.unpack("<II", d[q:q + 8])
                    rel[ri] = fid
                    q += 8
            for i in range(s["n"]):
                rec = d[rstart + i * self.record_size:rstart + (i + 1) * self.record_size]
                row = self._decode(rec, gidx * self.record_size, total_rec)
                gidx += 1
                rid = ids[i] if ids else row.get(self._id_name())
                if ids:
                    row[self._id_name()] = rid
                if rel:
                    rn = next((f["name"] for f in dd["fields"] if "relation" in f["ann"]), None)
                    if rn:
                        row[rn] = rel.get(i, 0)
                self.rows[rid] = row
            for i in range(0, len(copies), 2):
                new, old = copies[i], copies[i + 1]
                if old in self.rows:
                    r = dict(self.rows[old])
                    r[self._id_name()] = new
                    self.rows[new] = r

    def _read_sparse(self, d, s, si):
        """Sparse (offset-map) tables. Only all-string layouts such as Spell are supported."""
        p = s["end"]
        ids = struct.unpack("<%dI" % (s["idsz"] // 4), d[p:p + s["idsz"]]) if s["idsz"] else None
        p += s["idsz"]
        copies = struct.unpack("<%dI" % (s["copy"] * 2), d[p:p + 8 * s["copy"]]) if s["copy"] else ()
        p += 8 * s["copy"]
        om = [struct.unpack("<IH", d[p + i * 6:p + (i + 1) * 6]) for i in range(s["omc"])]
        p += s["omc"] * 6
        p += s["relsz"]
        omids = struct.unpack("<%dI" % s["omc"], d[p:p + 4 * s["omc"]]) if s["omc"] else ()
        fields = [f["name"] for f in self.inline]
        for i, (off, size) in enumerate(om):
            rid = omids[i] if omids else ids[i]
            parts = d[off:off + size].split(b"\0")
            row = {n: parts[j].decode("utf-8", "replace") if j < len(parts) else "" for j, n in enumerate(fields)}
            row[self._id_name()] = rid
            self.rows[rid] = row
        for i in range(0, len(copies), 2):
            if copies[i + 1] in self.rows:
                r = dict(self.rows[copies[i + 1]])
                r[self._id_name()] = copies[i]
                self.rows[copies[i]] = r

    def _id_name(self):
        for f in self.dd["fields"]:
            if "id" in f["ann"]:
                return f["name"]
        return "ID"

    def _decode(self, rec, recbase, total_rec):
        row = {}
        big = int.from_bytes(rec, "little")
        for i, f in enumerate(self.inline):
            if i >= len(self.fsi):
                break
            fs = self.fsi[i]
            ftype = self.columns.get(f["name"], ("int", None))[0]
            vals = []
            c = fs["comp"]
            if c == 0:
                bits = fs["bits"]
                each = bits // f["arr"]
                for a in range(f["arr"]):
                    v = (big >> (fs["off"] + a * each)) & ((1 << each) - 1)
                    vals.append(v)
            elif c in (1, 5):
                v = (big >> fs["off"]) & ((1 << fs["bits"]) - 1)
                if c == 5 and v >> (fs["bits"] - 1):
                    v -= 1 << fs["bits"]
                vals.append(v)
            elif c == 2:
                vals.append(None)  # filled below
                # needs record id; handled in post step
            elif c == 3:
                ix = (big >> fs["off"]) & ((1 << fs["bits"]) - 1)
                vals.append(struct.unpack("<I", self.pal[i][ix * 4:ix * 4 + 4])[0])
            elif c == 4:
                ix = (big >> fs["off"]) & ((1 << fs["bits"]) - 1)
                n = fs["v3"]
                for a in range(n):
                    vals.append(struct.unpack("<I", self.pal[i][(ix * n + a) * 4:(ix * n + a) * 4 + 4])[0])
            if c == 2:
                row[f["name"]] = ("__common__", i, fs["v1"])
                continue
            # type coercion
            out = []
            for a, v in enumerate(vals):
                if ftype in ("string", "locstring"):
                    if v == 0:
                        out.append("")
                    else:
                        pos = recbase + fs["off"] // 8 + a * (fs["bits"] // f["arr"] // 8 if c == 0 else 4) + v - total_rec
                        if pos < 0 or pos >= len(self.strs):
                            out.append("")
                        else:
                            e = self.strs.index(b"\0", pos)
                            out.append(self.strs[pos:e].decode("utf-8", "replace"))
                elif ftype == "float":
                    out.append(struct.unpack("<f", struct.pack("<I", v & 0xffffffff))[0])
                else:
                    out.append(fit_width(v, f["size"]))
            row[f["name"]] = out if f["arr"] > 1 else out[0]
        return row

    def finish(self):
        for rid, row in self.rows.items():
            for k, v in list(row.items()):
                if isinstance(v, tuple) and v and v[0] == "__common__":
                    field = self.inline[v[1]]
                    raw = self.common[v[1]].get(rid, v[2])
                    if self.columns.get(field["name"], ("int", None))[0] == "float":
                        row[k] = struct.unpack("<f", struct.pack("<I", raw & 0xffffffff))[0]
                    else:
                        row[k] = fit_width(raw, field["size"])
        return self


def load(casc, dbd_dir, fdid, name, locale="enUS", build=None):
    from casc import NotLocalError
    data, enc_chunks = casc.read_fdid(fdid, locale, allow_partial=True)
    cols, defs = parse_dbd(os.path.join(dbd_dir, name + ".dbd"))
    t = WDC(data, cols, defs, build, name).finish()
    t.enc_chunks = enc_chunks
    return t
