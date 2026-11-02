"""Read-only reader for MPQ archives, as used by the original WoW clients.

Opens archives for reading only and never executes anything from a client.
"""

import bz2
import os
import struct
import zlib

_FILE_IMPLODE = 0x00000100
_FILE_COMPRESS = 0x00000200
_FILE_ENCRYPTED = 0x00010000
_FILE_FIX_KEY = 0x00020000
_FILE_SINGLE_UNIT = 0x01000000
_FILE_DELETE_MARKER = 0x02000000
_FILE_SECTOR_CRC = 0x04000000
_FILE_EXISTS = 0x80000000


def _build_crypt_table():
    table = [0] * 0x500
    seed = 0x00100001
    for i in range(0x100):
        index = i
        for _ in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            high = (seed & 0xFFFF) << 16
            seed = (seed * 125 + 3) % 0x2AAAAB
            table[index] = high | (seed & 0xFFFF)
            index += 0x100
    return table


_CRYPT = _build_crypt_table()


def _hash(name, kind):
    seed1, seed2 = 0x7FED7FED, 0xEEEEEEEE
    for ch in name.upper().replace("/", "\\").encode("latin-1"):
        seed1 = _CRYPT[(kind << 8) + ch] ^ ((seed1 + seed2) & 0xFFFFFFFF)
        seed2 = (ch + seed1 + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
    return seed1


def _decrypt(data, key):
    words = struct.unpack(f"<{len(data) // 4}I", data[: len(data) // 4 * 4])
    seed = 0xEEEEEEEE
    out = []
    for word in words:
        seed = (seed + _CRYPT[0x400 + (key & 0xFF)]) & 0xFFFFFFFF
        plain = word ^ ((key + seed) & 0xFFFFFFFF)
        key = (((~key << 21) & 0xFFFFFFFF) + 0x11111111 | key >> 11) & 0xFFFFFFFF
        seed = (plain + seed + (seed << 5) + 3) & 0xFFFFFFFF
        out.append(plain)
    return struct.pack(f"<{len(out)}I", *out)


def _decompress(data, expected):
    if len(data) >= expected:
        return data
    method = data[0]
    payload = data[1:]
    if method == 0x02:
        return zlib.decompress(payload)
    if method == 0x10:
        return bz2.decompress(payload)
    raise ValueError(f"unsupported compression 0x{method:02x}")


class Mpq:
    def __init__(self, path):
        self.path = path
        self._f = open(path, "rb")
        self._offset = self._find_header()
        self._f.seek(self._offset)
        (_, _, _, self.version, sector_shift, hash_pos, block_pos, hash_n, block_n) = (
            struct.unpack("<4sIIHHIIII", self._f.read(32))
        )
        self._sector_size = 512 << sector_shift
        self._hash = self._read_table(hash_pos, hash_n, "(hash table)")
        self._block = self._read_table(block_pos, block_n, "(block table)")

    def _find_header(self):
        size = os.path.getsize(self.path)
        for offset in range(0, size, 0x200):
            self._f.seek(offset)
            if self._f.read(4) == b"MPQ\x1a":
                return offset
        raise ValueError(f"no MPQ header in {self.path}")

    def _read_table(self, pos, count, key_name):
        self._f.seek(self._offset + pos)
        raw = _decrypt(self._f.read(count * 16), _hash(key_name, 3))
        return [struct.unpack_from("<4I", raw, i * 16) for i in range(count)]

    def _find(self, name):
        if not self._hash:
            return None
        start = _hash(name, 0) % len(self._hash)
        name_a, name_b = _hash(name, 1), _hash(name, 2)
        best = None
        for i in range(len(self._hash)):
            a, b, locale, block = self._hash[(start + i) % len(self._hash)]
            if block == 0xFFFFFFFF:
                break
            if a == name_a and b == name_b and block < len(self._block):
                # Locale 0 is the neutral entry; prefer it, else take any.
                if best is None or (locale & 0xFFFF) == 0:
                    best = block
        return best

    def has(self, name):
        block = self._find(name)
        return block is not None and bool(self._block[block][3] & _FILE_EXISTS)

    def is_deleted(self, name):
        block = self._find(name)
        return block is not None and bool(self._block[block][3] & _FILE_DELETE_MARKER)

    def read(self, name):
        block = self._find(name)
        if block is None:
            raise KeyError(name)
        pos, packed, size, flags = self._block[block]
        if not flags & _FILE_EXISTS or flags & _FILE_DELETE_MARKER:
            raise KeyError(name)
        if flags & _FILE_IMPLODE:
            raise ValueError(f"PKWARE implode is not supported: {name}")
        self._f.seek(self._offset + pos)
        raw = self._f.read(packed)
        key = None
        if flags & _FILE_ENCRYPTED:
            key = _hash(name.replace("/", "\\").split("\\")[-1], 3)
            if flags & _FILE_FIX_KEY:
                key = ((key + pos) ^ size) & 0xFFFFFFFF
        if flags & _FILE_SINGLE_UNIT:
            if key is not None:
                raw = _decrypt(raw, key) + raw[len(raw) // 4 * 4 :]
            return _decompress(raw, size) if flags & _FILE_COMPRESS else raw
        return self._read_sectors(raw, size, flags, key)

    def _read_sectors(self, raw, size, flags, key):
        sectors = (size + self._sector_size - 1) // self._sector_size
        if not flags & _FILE_COMPRESS:
            offsets = [
                min(i * self._sector_size, len(raw)) for i in range(sectors + 1)
            ]
        else:
            count = sectors + 1 + (1 if flags & _FILE_SECTOR_CRC else 0)
            table = raw[: count * 4]
            if key is not None:
                table = _decrypt(table, (key - 1) & 0xFFFFFFFF)
            offsets = struct.unpack(f"<{count}I", table)
        out = bytearray()
        for i in range(sectors):
            chunk = raw[offsets[i] : offsets[i + 1]]
            if key is not None:
                chunk = _decrypt(chunk, (key + i) & 0xFFFFFFFF) + chunk[len(chunk) // 4 * 4 :]
            expected = min(self._sector_size, size - i * self._sector_size)
            out += _decompress(chunk, expected) if flags & _FILE_COMPRESS else chunk
        return bytes(out)

    def listfile(self):
        if not self.has("(listfile)"):
            return []
        text = self.read("(listfile)").decode("latin-1")
        return [line.strip() for line in text.splitlines() if line.strip()]

    def close(self):
        self._f.close()


class Client:
    """A client's archives, with later patches taking priority."""

    def __init__(self, data_dir, locale=None):
        """Pass locale when a client ships several, or their patches collide."""
        self.data_dir = data_dir
        paths = []
        for root, _, names in os.walk(data_dir):
            folder = os.path.relpath(root, data_dir).split(os.sep)[0]
            if locale and folder not in (".", locale):
                continue
            paths += [os.path.join(root, n) for n in names if n.lower().endswith(".mpq")]
        self.archives = [Mpq(p) for p in sorted(paths, key=self._priority, reverse=True)]

    @staticmethod
    def _priority(path):
        # Higher wins: patch-<locale>-2 > patch-<locale> > patch-2 > patch > base.
        name = os.path.basename(path).lower()[:-4]
        if not name.startswith("patch"):
            return (0, 0, 0, name)
        parts = name.split("-")[1:]
        number = int(parts[-1]) if parts and parts[-1].isdigit() else 1
        is_locale = any(not part.isdigit() for part in parts)
        return (1, int(is_locale), number, name)

    def provider(self, name):
        for archive in self.archives:
            if archive.is_deleted(name):
                return None
            if archive.has(name):
                return archive
        return None

    def read(self, name):
        archive = self.provider(name)
        if archive is None:
            raise KeyError(name)
        return archive.read(name)


class Dbc:
    """A WDBC table: fixed-size records of 32-bit fields plus a string block."""

    def __init__(self, data):
        magic, self.count, self.fields, self.size, strings = struct.unpack_from(
            "<4s4I", data
        )
        if magic != b"WDBC":
            raise ValueError(f"not a WDBC file: {magic!r}")
        self._records = data[20 : 20 + self.count * self.size]
        self._strings = data[20 + self.count * self.size :]

    def row(self, index):
        start = index * self.size
        return struct.unpack_from(f"<{self.fields}I", self._records, start)

    def rows(self):
        return (self.row(i) for i in range(self.count))

    def string(self, offset):
        end = self._strings.index(b"\0", offset)
        return self._strings[offset:end].decode("utf-8", "replace")
