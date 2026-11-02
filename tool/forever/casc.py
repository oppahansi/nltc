"""Minimal read-only CASC reader (local storage only, stdlib only).

Opens files with mode 'rb' only. Never writes to the install, never touches
shmem/lock files, and refuses encrypted BLTE chunks (raises EncryptedError)
instead of trying to decrypt them.
"""
import os, re, struct, zlib, bisect


class EncryptedError(Exception):
    pass


class NotLocalError(Exception):
    pass


def parse_config(path):
    out = {}
    with open(path, "r", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            k, _, v = line.partition("=")
            out[k.strip()] = v.strip()
    return out


def blte_decode(buf, allow_partial=False):
    """Decode BLTE. Encrypted chunks raise EncryptedError (or zero-fill and
    report if allow_partial, which keeps other sections readable)."""
    if buf[:4] != b"BLTE":
        raise ValueError("not BLTE")
    hsize = struct.unpack(">I", buf[4:8])[0]
    chunks = []
    enc = 0
    if hsize == 0:
        chunks.append((buf[8:], None))
    else:
        flags = buf[8]
        count = struct.unpack(">I", b"\0" + buf[9:12])[0]
        off = 12
        pos = hsize
        for _ in range(count):
            c, d = struct.unpack(">II", buf[off:off + 8])
            off += 24
            chunks.append((buf[pos:pos + c], d))
            pos += c
    out = bytearray()
    for data, dsize in chunks:
        mode = data[:1]
        if mode == b"N":
            out += data[1:]
        elif mode == b"Z":
            out += zlib.decompress(data[1:])
        elif mode == b"E":
            if not allow_partial or dsize is None:
                raise EncryptedError("encrypted BLTE chunk")
            enc += 1
            out += b"\0" * dsize
        else:
            raise ValueError("unsupported BLTE mode %r" % mode)
    return bytes(out), enc


class Casc:
    def __init__(self, install, product=None):
        """product selects a row of a shared install's .build.info; default is the first."""
        self.install = install
        info_lines = open(os.path.join(install, ".build.info")).read().splitlines()
        hdr = [h.split("!")[0] for h in info_lines[0].split("|")]
        rows = [dict(zip(hdr, line.split("|"))) for line in info_lines[1:] if line.strip()]
        if product is None:
            self.info = rows[0]
        else:
            match = [r for r in rows if r.get("Product") == product]
            if len(match) != 1:
                raise ValueError("product %s: %d rows in .build.info" % (product, len(match)))
            self.info = match[0]
        bk = self.info["Build Key"]
        self.build = parse_config(
            os.path.join(install, "Data", "config", bk[:2], bk[2:4], bk))
        self.data_dir = os.path.join(install, "Data", "data")
        self._load_indices()
        self._load_encoding()
        self._load_root()

    # ---- local indices
    def _load_indices(self):
        newest = {}
        for n in os.listdir(self.data_dir):
            m = re.fullmatch(r"([0-9a-f]{2})([0-9a-f]{8})\.idx", n)
            if m:
                b, v = m.group(1), int(m.group(2), 16)
                if b not in newest or newest[b][0] < v:
                    newest[b] = (v, n)
        self.idx = {}
        for b, (v, n) in newest.items():
            with open(os.path.join(self.data_dir, n), "rb") as f:
                raw = f.read()
            hlen = struct.unpack("<I", raw[:4])[0]
            ver, bucket, extra, slen, olen, klen, obits = struct.unpack(
                "<HBBBBBB", raw[8:16])
            assert (slen, olen, klen) == (4, 5, 9), (slen, olen, klen)
            # header block padded to 16 bytes, followed by the entry-block header
            start = ((8 + hlen + 15) & ~15)
            esize = struct.unpack("<I", raw[start:start + 4])[0]
            p = start + 8
            for i in range(esize // 18):
                e = raw[p + i * 18:p + i * 18 + 18]
                key = e[:9]
                off = int.from_bytes(e[9:14], "big")
                size = struct.unpack("<I", e[14:18])[0]
                arc = off >> obits
                offset = off & ((1 << obits) - 1)
                self.idx.setdefault(key, (arc, offset, size))

    def has_ekey(self, ekey):
        return bytes.fromhex(ekey)[:9] in self.idx if isinstance(ekey, str) else ekey[:9] in self.idx

    def read_ekey(self, ekey, allow_partial=False):
        ek = bytes.fromhex(ekey) if isinstance(ekey, str) else ekey
        loc = self.idx.get(ek[:9])
        if loc is None:
            raise NotLocalError(ek.hex())
        arc, off, size = loc
        with open(os.path.join(self.data_dir, "data.%03d" % arc), "rb") as f:
            f.seek(off)
            raw = f.read(size)
        data, enc = blte_decode(raw[30:], allow_partial)
        return (data, enc) if allow_partial else data

    # ---- encoding
    def _load_encoding(self):
        ek = self.build["encoding"].split()[1]
        e = self.read_ekey(ek)
        assert e[:2] == b"EN"
        hc, he = e[3], e[4]
        cps, eps = struct.unpack(">HH", e[5:9])
        cn, en = struct.unpack(">II", e[9:17])
        espec = struct.unpack(">I", e[18:22])[0]
        p = 22 + espec
        p += cn * (hc + 16)
        self.c2e = {}
        for i in range(cn):
            pg = e[p:p + cps * 1024]
            p += cps * 1024
            q = 0
            while q + 6 + hc <= len(pg) and pg[q] != 0:
                k = pg[q]
                ck = pg[q + 6:q + 6 + hc]
                self.c2e[ck] = [pg[q + 6 + hc + j * he:q + 6 + hc + (j + 1) * he] for j in range(k)]
                q += 6 + hc + k * he

    def ckey_to_ekey(self, ck):
        return self.c2e.get(ck)

    # ---- root
    def _load_root(self):
        ck = bytes.fromhex(self.build["root"].split()[0])
        r = self.read_ekey(self.c2e[ck][0])
        p = 0
        self.root_version = 0
        if r[:4] == b"TSFM":
            hsize, ver = struct.unpack("<II", r[4:12])
            if hsize < 0x1000 and ver < 0x100:  # new-style header
                self.root_version = ver
                self.root_total, self.root_named = struct.unpack("<II", r[12:20])
                p = hsize
            else:
                self.root_total, self.root_named = hsize, ver
                p = 12
        else:
            raise ValueError("unexpected root magic %r" % r[:4])
        self.root = {}  # fdid -> list[(localeflags, contentflags, ckey)]
        self.root_blocks = []
        n = len(r)
        while p < n:
            if self.root_version >= 2:
                cnt, loc, u1, u2, u3 = struct.unpack("<IIIIB", r[p:p + 17])
                cf = u1 | u2 | (u3 << 17)
                p += 17
            else:
                cnt, cf, loc = struct.unpack("<III", r[p:p + 12])
                p += 12
            deltas = struct.unpack("<%di" % cnt, r[p:p + 4 * cnt])
            p += 4 * cnt
            fid = -1
            fids = []
            for d in deltas:
                fid = fid + 1 + d
                fids.append(fid)
            cks = r[p:p + 16 * cnt]
            p += 16 * cnt
            if not (cf & 0x10000000) and self.root_named != self.root_total or (not (cf & 0x10000000)):
                p += 8 * cnt  # name hashes
            self.root_blocks.append((cnt, loc, cf))
            for i, fd in enumerate(fids):
                self.root.setdefault(fd, []).append((loc, cf, cks[i * 16:i * 16 + 16]))

    LOCALES = {"enUS": 0x2, "koKR": 0x4, "frFR": 0x10, "deDE": 0x20, "zhCN": 0x40,
               "esES": 0x80, "zhTW": 0x100, "enGB": 0x200, "esMX": 0x1000,
               "ruRU": 0x2000, "ptBR": 0x4000, "itIT": 0x8000, "ptPT": 0x10000}

    def entries(self, fdid, locale=None):
        out = []
        for loc, cf, ck in self.root.get(fdid, []):
            if locale is None or (loc & self.LOCALES[locale]):
                out.append((loc, cf, ck))
        return out

    def read_fdid(self, fdid, locale="enUS", allow_partial=False):
        es = self.entries(fdid, locale)
        if not es:
            raise KeyError("fdid %d not in root for %s" % (fdid, locale))
        last = None
        for loc, cf, ck in es:
            eks = self.c2e.get(ck)
            if not eks:
                continue
            for ek in eks:
                try:
                    return self.read_ekey(ek, allow_partial)
                except NotLocalError as e:
                    last = e
        raise NotLocalError("fdid %d locale %s: %s" % (fdid, locale, last))
