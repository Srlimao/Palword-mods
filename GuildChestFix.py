r"""Guild Chest Fix, a companion tool for the Guild Storage Expander mod.

Expands the Guild Chest of guilds that already existed before the mod was
installed. The mod's larger chest (444 slots) only applies to guilds created
after it is enabled, because Palworld stores each guild's chest size inside
the save file at guild creation. This tool edits that stored number.

It changes ONE integer per guild (the chest's SlotNum), verifies every byte
of the edit, keeps a backup, and refuses to write anything it is not sure
about. It never shrinks a chest and never touches items.

Usage:
  GuildChestFix.exe                     interactive (world picker)
  GuildChestFix.exe <path\Level.sav>    fix that save directly
  GuildChestFix.exe <path> --yes        no confirmation prompt (scripting)
  GuildChestFix.exe --slots 70 ...      use a custom size from 54 to 444
  GuildChestFix.exe --gamepass [dir]    copy Game Pass saves out, read only
"""

import ctypes
import glob
import hashlib
import io
import contextlib
import os
import re
import shutil
import struct
import subprocess
import sys
import time
import urllib.request
import uuid
import zipfile

from palworld_save_tools.gvas import GvasFile, GvasHeader
from palworld_save_tools.paltypes import PALWORLD_TYPE_HINTS
from palworld_save_tools import palsav
from palworld_save_tools.archive import FArchiveReader, FArchiveWriter

# ------------------------------------------- save format future proofing
# palworld-save-tools 0.24.0 predates data that newer Palworld saves
# contain, and every game update can add more. Rather than chase each
# update after it breaks someone, three layers make the parser survive
# anything the game adds. Unknown data is preserved, never interpreted,
# and this tool's byte for byte edit checks still guard every write.

# Layer 1. Map values. The library's map parser only knows Struct, Enum,
# Name, Int and Bool values. Teach it every remaining type whose byte
# format is unambiguous (a mid 2026 update already ships Int64 timestamps
# in worldSaveData.LevelObjectRecoverPartySaveData). ByteProperty is left
# out on purpose, in maps it can be a raw byte or an enum name and a
# wrong guess would corrupt the save.
_MAP_VALUE_CODECS = {
    "Int64Property": "i64",
    "UInt64Property": "u64",
    "UInt32Property": "u32",
    "Int16Property": "i16",
    "UInt16Property": "u16",
    "FloatProperty": "float",
    "DoubleProperty": "double",
    "StrProperty": "fstring",
}

_orig_read_prop_value = FArchiveReader.prop_value
def _read_prop_value(self, type_name, struct_type_name, path):
    codec = _MAP_VALUE_CODECS.get(type_name)
    if codec:
        return getattr(self, codec)()
    return _orig_read_prop_value(self, type_name, struct_type_name, path)
FArchiveReader.prop_value = _read_prop_value

_orig_write_prop_value = FArchiveWriter.prop_value
def _write_prop_value(self, type_name, struct_type_name, value):
    codec = _MAP_VALUE_CODECS.get(type_name)
    if codec:
        getattr(self, codec)(value)
        return
    return _orig_write_prop_value(self, type_name, struct_type_name, value)
FArchiveWriter.prop_value = _write_prop_value

# Layer 2. SetProperty. Newer saves store sets, for example
# worldSaveData.InLockerCharacterInstanceIDArray. The library does not
# know the type at all. A set serializes like a map without values:
# element type, optional guid, a removed count that is always zero in
# saves, an element count, then the raw elements. The element parse is
# only trusted when it consumes exactly the declared byte count,
# otherwise the set is carried through raw by layer 3.

# Layer 3. Anything else. Every property record declares its own byte
# size, so a type this tool has never heard of can be carried through
# losslessly: capture the raw bytes and write them back untouched. The
# capture is only accepted when exactly one candidate layout lands on a
# clean next property boundary, otherwise the original error is raised.
# The tool never guesses.

# Layer 4. The declared size doubles as a checksum for every property at
# every nesting depth. After each parse the consumed byte count must
# match the declaration exactly. Any property that raises or comes up
# short or long is rolled back and carried through raw via layer 3, so a
# single wrong assumption can never push the rest of the file out of
# step and spray garbage. Errors shown to the user are capped in length.

_UNKNOWN_ERROR_MARKS = (
    "Unknown type:",
    "Unknown array type:",
    "Unknown property value type:",
)


def short_error(e):
    msg = str(e)
    if len(msg) > 300:
        msg = msg[:300] + " ... error text shortened, %d characters total" % len(msg)
    return msg


def _fstring_len(s):
    """Bytes the library writes for this string."""
    if s == "":
        return 4
    if s.isascii():
        return 4 + len(s) + 1
    return 4 + len(s.encode("utf-16-le", errors="surrogatepass")) + 2


def _guid_len(prop):
    return 17 if prop.get("id") is not None else 1


def _expected_consumed(type_name, prop, size):
    """Exact byte count property() must have consumed for this record, or
    None when the framing is owned elsewhere (custom rawdata readers)."""
    if "opaque_raw" in prop:
        return len(prop["opaque_raw"])
    if "custom_type" in prop:
        return None
    if type_name == "StructProperty":
        return _fstring_len(prop["struct_type"]) + 16 + _guid_len(prop) + size
    if type_name in ("EnumProperty", "ByteProperty"):
        return _fstring_len(prop["value"]["type"]) + _guid_len(prop) + size
    if type_name == "ArrayProperty":
        return _fstring_len(prop["array_type"]) + _guid_len(prop) + size
    if type_name == "SetProperty":
        return _fstring_len(prop["set_type"]) + _guid_len(prop) + size
    if type_name == "MapProperty":
        return (_fstring_len(prop["key_type"]) + _fstring_len(prop["value_type"])
                + _guid_len(prop) + size)
    if type_name == "BoolProperty":
        return 1 + _guid_len(prop) + size
    return _guid_len(prop) + size


def _sane_fstring(reader):
    """Read an fstring only if it looks like a real one, else None."""
    head = reader.data.read(4)
    if len(head) != 4:
        return None
    (n,) = struct.unpack("<i", head)
    if n == 0:
        return ""
    if 0 < n <= 120:
        b = reader.data.read(n)
        if len(b) != n or b[-1:] != b"\x00":
            return None
        body = b[:-1]
        if not all(32 <= c < 127 for c in body):
            return None
        return body.decode("ascii")
    if -120 <= n < 0:
        b = reader.data.read(-n * 2)
        if len(b) != -n * 2 or b[-2:] != b"\x00\x00":
            return None
        try:
            return b[:-2].decode("utf-16-le")
        except UnicodeDecodeError:
            return None
    return None


def _boundary_ok(reader, pos):
    """True when pos is the start of another property record or a None
    terminator, which is what must follow a fully consumed property."""
    if pos <= 0 or pos >= reader.size:
        return False
    keep = reader.data.tell()
    try:
        reader.data.seek(pos)
        name = _sane_fstring(reader)
        if not name:
            return False
        if name == "None":
            return True
        type_name = _sane_fstring(reader)
        return type_name is not None and type_name.endswith("Property")
    finally:
        reader.data.seek(keep)


def _capture_opaque(reader, start, declared_size):
    """Return the raw bytes of the property whose body starts at start, or
    None when the end cannot be established beyond doubt. The declared size
    excludes any leading type strings and the optional guid, so try 0 to 2
    leading strings and both guid sizes and demand exactly one clean fit."""
    ends = set()
    for n_extras in range(3):
        reader.data.seek(start)
        parsed_all = True
        for _ in range(n_extras):
            if _sane_fstring(reader) is None:
                parsed_all = False
                break
        if not parsed_all:
            continue
        base = reader.data.tell()
        for guid_len in (1, 17):
            ends.add(base + guid_len + declared_size)
    fits = [e for e in sorted(ends) if _boundary_ok(reader, e)]
    if len(fits) != 1:
        reader.data.seek(start)
        return None
    end = fits[0]
    reader.data.seek(start)
    raw = reader.data.read(end - start)
    return raw


def _try_read_set(reader, declared_size, path):
    """Parse a SetProperty body, or None when the bytes do not fit the
    expected shape exactly."""
    try:
        set_type = reader.fstring()
        _id = reader.optional_guid()
        body_start = reader.data.tell()
        if reader.u32() != 0:  # removed element count, zero in real saves
            return None
        count = reader.u32()
        if count > declared_size:
            return None
        elem_path = path + ".Key"
        if set_type == "StructProperty":
            elem_struct_type = reader.get_type_or(elem_path, "Guid")
        else:
            elem_struct_type = None
        values = [reader.prop_value(set_type, elem_struct_type, elem_path)
                  for _ in range(count)]
        if reader.data.tell() - body_start != declared_size:
            return None
        return {
            "set_type": set_type,
            "set_struct_type": elem_struct_type,
            "id": _id,
            "value": values,
            "type": "SetProperty",
        }
    except Exception:
        return None


_orig_read_property = FArchiveReader.property
def _read_property(self, type_name, size, path, nested_caller_path=""):
    start = self.data.tell()
    if type_name == "SetProperty" and path not in self.custom_properties:
        parsed = _try_read_set(self, size, path)
        if parsed is not None:
            return parsed
        self.data.seek(start)
        raw = _capture_opaque(self, start, size)
        if raw is None:
            raise Exception("Unknown type: %s (%s)" % (type_name, path))
        return {"type": type_name, "opaque_raw": raw, "opaque_size": size}
    try:
        return _orig_read_property(self, type_name, size, path, nested_caller_path)
    except Exception as e:
        if not any(mark in str(e) for mark in _UNKNOWN_ERROR_MARKS):
            raise
        self.data.seek(start)
        raw = _capture_opaque(self, start, size)
        if raw is None:
            raise
        return {"type": type_name, "opaque_raw": raw, "opaque_size": size}
FArchiveReader.property = _read_property


_orig_properties_until_end = FArchiveReader.properties_until_end
def _properties_until_end(self, path=""):
    properties = {}
    while True:
        name = self.fstring()
        if name == "None":
            break
        type_name = self.fstring()
        size = self.u64()
        prop_path = "%s.%s" % (path, name)
        start = self.data.tell()
        prop = None
        parse_error = None
        try:
            prop = self.property(type_name, size, prop_path)
            consumed = self.data.tell() - start
            expected = _expected_consumed(type_name, prop, size)
            if expected is not None and consumed != expected:
                parse_error = ValueError(
                    "property %s (%s) consumed %d bytes, expected %d"
                    % (prop_path, type_name, consumed, expected))
        except Exception as e:
            parse_error = e
        if parse_error is not None:
            self.data.seek(start)
            raw = _capture_opaque(self, start, size)
            if raw is None:
                raise parse_error
            prop = {"type": type_name, "opaque_raw": raw, "opaque_size": size}
        properties[name] = prop
    return properties
FArchiveReader.properties_until_end = _properties_until_end


# Layer 5. The header. Its layout has no size framing, so an unknown
# layout cannot be recovered, but it can always be refused safely and
# clearly. After a successful read the header is serialized again and
# must reproduce the original bytes exactly, otherwise the tool refuses
# up front rather than corrupt the header on a later write.
_orig_header_read = GvasHeader.read
def _header_read(reader):
    start = reader.data.tell()
    try:
        header = _orig_header_read(reader)
    except Exception as e:
        raise ValueError(
            "this save's header is from a newer game or engine version this "
            "tool does not know yet, look for a tool update (%s)" % short_error(e))
    end = reader.data.tell()
    w = FArchiveWriter({})
    header.write(w)
    reader.data.seek(start)
    original = reader.data.read(end - start)
    reader.data.seek(end)
    if w.bytes() != original:
        raise ValueError(
            "this save's header does not read back identically, refusing to "
            "continue so nothing can be corrupted")
    return header
GvasHeader.read = _header_read


_orig_write_property_inner = FArchiveWriter.property_inner
def _write_property_inner(self, property_type, property):
    if "opaque_raw" in property:
        self.write(property["opaque_raw"])
        return property["opaque_size"]
    if property_type == "SetProperty" and "custom_type" not in property:
        self.fstring(property["set_type"])
        self.optional_guid(property.get("id", None))
        set_writer = self.copy()
        set_writer.u32(0)
        set_writer.u32(len(property["value"]))
        for v in property["value"]:
            set_writer.prop_value(
                property["set_type"], property["set_struct_type"], v)
        buf = set_writer.bytes()
        self.write(buf)
        return len(buf)
    return _orig_write_property_inner(self, property_type, property)
FArchiveWriter.property_inner = _write_property_inner
# ----------------------------------------- end save format future proofing

VERSION = "1.4.0"
TARGET_SLOTS = 444  # matches the Guild Storage Expander mod

# Oodle DLL source: automated Unreal Engine Oodle builds (github.com/WorkingRobot/OodleUE),
# pinned to the exact release + hash this tool was tested against.
OODLE_ZIP_URL = ("https://github.com/WorkingRobot/OodleUE/releases/download/"
                 "2026-06-04-1357/msvc-x64-release.zip")
OODLE_ZIP_SHA256 = "08844ec260e40134ce6089ffe2003d6f862cd2abf1ebfb62a3fa8d2f69f48a2b"
OODLE_ZIP_MEMBER = "bin/oodle-data-shared.dll"

CACHE_DIR = os.path.join(os.environ.get("LOCALAPPDATA", os.path.expanduser("~")),
                         "GuildChestFix")
SAVE_ROOT = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Pal", "Saved", "SaveGames")

KRAKEN = 8
OODLE_LEVEL = 4


def say(msg=""):
    print(msg, flush=True)


def ask(prompt):
    try:
        return input(prompt)
    except EOFError:
        say()
        sys.exit(0)


def pause_exit(code=0):
    # deliberately not ask(): the exit code must survive a closed stdin
    if sys.stdin.isatty():
        try:
            input("\nPress Enter to close. ")
        except EOFError:
            pass
    sys.exit(code)


# --------------------------------------------------------------------- Oodle

class Oodle:
    def __init__(self, path):
        self.path = path
        dll = ctypes.WinDLL(path)
        dll.OodleLZ_Decompress.restype = ctypes.c_size_t
        dll.OodleLZ_Decompress.argtypes = [
            ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_size_t,
            ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p,
            ctypes.c_size_t, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p,
            ctypes.c_size_t, ctypes.c_int]
        dll.OodleLZ_Compress.restype = ctypes.c_size_t
        dll.OodleLZ_Compress.argtypes = [
            ctypes.c_int, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p,
            ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p,
            ctypes.c_void_p, ctypes.c_size_t]
        self.dll = dll

    def decompress(self, comp, raw_len):
        out = ctypes.create_string_buffer(raw_len)
        n = self.dll.OodleLZ_Decompress(comp, len(comp), out, raw_len,
                                        1, 0, 0, None, 0, None, None, None, 0, 3)
        if n != raw_len:
            raise ValueError("Oodle decompress returned %d, expected %d" % (n, raw_len))
        return out.raw

    def compress(self, raw):
        bound = len(raw) + 274 * ((len(raw) + 0x3FFFF) // 0x40000)
        out = ctypes.create_string_buffer(bound)
        n = self.dll.OodleLZ_Compress(KRAKEN, raw, len(raw), out, OODLE_LEVEL,
                                      None, None, None, None, 0)
        if n <= 0:
            raise ValueError("Oodle compress failed (%d)" % n)
        return out.raw[:n]

    def selftest(self):
        sample = b"GuildChestFix oodle self test " * 200
        return self.decompress(self.compress(sample), len(sample)) == sample


def try_load_oodle(path):
    try:
        oo = Oodle(path)
        if oo.selftest():
            return oo
    except Exception:
        pass
    return None


def download_oodle():
    say("  Downloading the Oodle codec (about 7 MB, one time only)...")
    req = urllib.request.Request(OODLE_ZIP_URL,
                                 headers={"User-Agent": "GuildChestFix/" + VERSION})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    digest = hashlib.sha256(data).hexdigest()
    if digest != OODLE_ZIP_SHA256:
        raise ValueError("download did not match the expected checksum")
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        dll_bytes = z.read(OODLE_ZIP_MEMBER)
    os.makedirs(CACHE_DIR, exist_ok=True)
    dest = os.path.join(CACHE_DIR, "oodle-data-shared.dll")
    with open(dest, "wb") as f:
        f.write(dll_bytes)
    say("  Saved to %s" % dest)
    return dest


def steam_scan():
    """Find an oo2core DLL inside any installed Steam game (fallback source)."""
    hits = []
    steam = os.path.join(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"),
                         "Steam")
    libs = {steam}
    vdf = os.path.join(steam, "steamapps", "libraryfolders.vdf")
    if os.path.isfile(vdf):
        try:
            text = open(vdf, encoding="utf-8", errors="ignore").read()
            for m in re.finditer(r'"path"\s+"([^"]+)"', text):
                libs.add(m.group(1).replace("\\\\", "\\"))
        except OSError:
            pass
    for lib in libs:
        common = os.path.join(lib, "steamapps", "common")
        if not os.path.isdir(common):
            continue
        hits += glob.glob(os.path.join(common, "*", "oo2core_*_win64.dll"))
        hits += glob.glob(os.path.join(common, "*", "Engine", "Binaries", "ThirdParty",
                                       "Oodle", "*", "win", "redist",
                                       "oo2core_*_win64.dll"))
    return hits


def get_oodle():
    """Locate a working Oodle DLL: next to the exe, cached, downloaded, or from Steam."""
    exe_dir = (os.path.dirname(sys.executable) if getattr(sys, "frozen", False)
               else os.path.dirname(os.path.abspath(__file__)))
    candidates = (glob.glob(os.path.join(exe_dir, "oodle-data-shared.dll"))
                  + glob.glob(os.path.join(exe_dir, "oo2core_*_win64.dll"))
                  + glob.glob(os.path.join(CACHE_DIR, "oodle-data-shared.dll")))
    for c in candidates:
        oo = try_load_oodle(c)
        if oo:
            return oo

    say("Palworld saves are compressed with the Oodle codec, which cannot be")
    say("bundled with this tool for licensing reasons.")
    try:
        path = download_oodle()
        oo = try_load_oodle(path)
        if oo:
            return oo
        say("  Downloaded DLL failed its self test.")
    except Exception as e:
        say("  Download failed: %s" % e)

    say("  Looking for the codec in your installed Steam games instead...")
    for hit in steam_scan():
        oo = try_load_oodle(hit)
        if oo:
            say("  Using %s" % hit)
            return oo

    say("")
    say("Could not get the Oodle codec automatically. If you have ANY game that")
    say("ships a file named like oo2core_9_win64.dll, enter its full path here.")
    while True:
        p = ask("Path to oo2core DLL (or Q to quit): ").strip().strip('"')
        if p.lower() == "q":
            sys.exit(0)
        if os.path.isfile(p):
            oo = try_load_oodle(p)
            if oo:
                return oo
            say("That DLL did not pass the self test. Try another one.")
        else:
            say("No file at that path.")


# --------------------------------------------------- save container (PlM/PlZ)

def read_save(path, oodle):
    """Return (gvas_bytes, container_format). Format is kept so the file is
    written back exactly the way it came in."""
    data = open(path, "rb").read()
    if len(data) > 12 and data[8:11] == b"PlM":
        if data[11:12] != b"1":
            raise ValueError(
                "this save uses a container variant (%s) this tool does not "
                "know yet, look for a tool update" % data[8:12])
        raw_len, comp_len = struct.unpack_from("<II", data, 0)
        if raw_len == 0 or raw_len > 0x40000000:
            raise ValueError("the save header declares an impossible size, "
                             "the file is corrupt")
        comp = data[12:12 + comp_len]
        if len(comp) != comp_len:
            raise ValueError("truncated save file")
        return oodle.decompress(comp, raw_len), ("PlM1", None)
    # older zlib container ("PlZ") is handled by the save tools library
    gvas, save_type = palsav.decompress_sav_to_gvas(data)
    return gvas, ("PlZ", save_type)


def write_save(path, gvas_bytes, fmt, oodle):
    kind, save_type = fmt
    if kind == "PlM1":
        comp = oodle.compress(gvas_bytes)
        with open(path, "wb") as f:
            f.write(struct.pack("<II", len(gvas_bytes), len(comp)))
            f.write(b"PlM1")
            f.write(comp)
    else:
        with open(path, "wb") as f:
            f.write(palsav.compress_gvas_to_sav(gvas_bytes, save_type))


def parse_gvas(gvas_bytes):
    # the parser prints harmless "Struct type ... not found" guesses, hide them
    with contextlib.redirect_stdout(io.StringIO()):
        return GvasFile.read(gvas_bytes, PALWORLD_TYPE_HINTS, {}, allow_nan=True)


# ------------------------------------------------------------- guild chests

def container_key_hex(guid16):
    """Container GUIDs are stored as four little endian u32s. The container
    map key prints them byte swapped per u32."""
    a, b, c, d = struct.unpack("<IIII", guid16)
    return struct.pack(">IIII", a, b, c, d).hex()


def normalize_key(key):
    u = key["ID"]["value"] if isinstance(key, dict) and "ID" in key else key
    return str(u).replace("-", "").lower()


def find_guild_chests(wsd):
    """Yield {guild_id, entry, slot_num, filled} for every guild storage
    container in the save, plus a list of readable skip notes."""
    found, notes = [], []
    gx = wsd.get("GuildExtraSaveDataMap")
    if not gx:
        return found, ["This save has no guild data (GuildExtraSaveDataMap missing)."]
    ics = wsd.get("ItemContainerSaveData")
    newer = ("The %s data in this save is stored in a newer format this tool "
             "version cannot read. Look for a tool update.")
    if "opaque_raw" in gx or not isinstance(gx.get("value"), list):
        return found, [newer % "guild"]
    if ics is None or "opaque_raw" in ics or not isinstance(ics.get("value"), list):
        return found, [newer % "item container"]
    containers = {}
    for e in ics["value"]:
        try:
            containers[normalize_key(e["key"])] = e
        except (KeyError, TypeError):
            continue
    for e in gx["value"]:
        short = "unknown"
        try:
            short = normalize_key(e["key"])[:8]
            try:
                values = e["value"]["GuildItemStorage"]["value"]["RawData"]["value"]["values"]
            except (KeyError, TypeError):
                notes.append("Guild %s has no chest storage record, skipped." % short)
                continue
            raw = bytes(values)
            if len(raw) < 16 or raw[:16] == b"\x00" * 16:
                notes.append("Guild %s chest storage is not initialized, skipped." % short)
                continue
            key = container_key_hex(raw[:16])
            entry = containers.get(key)
            if entry is None:
                notes.append("Guild %s chest container %s was not found in the save, skipped."
                             % (short, key[:8]))
                continue
            v = entry["value"]
            found.append({
                "guild_id": short,
                "entry": entry,
                "slot_num": v["SlotNum"]["value"],
                "filled": len(v["Slots"]["value"]["values"]),
            })
        except Exception:
            notes.append("Guild %s could not be read, skipped." % short)
    return found, notes


# ------------------------------------------------------------- verification

def verify_diff(orig, new, old_values, target):
    """The only bytes that may differ between the original and edited GVAS are
    the SlotNum int32s we changed, old to target, one cluster per container."""
    if len(orig) != len(new):
        raise ValueError("edited save changed length (%d to %d)" % (len(orig), len(new)))
    diffs = [i for i, (a, b) in enumerate(zip(orig, new)) if a != b]
    clusters = []
    for i in diffs:
        if clusters and i - clusters[-1][-1] <= 3:
            clusters[-1].append(i)
        else:
            clusters.append([i])
    if len(clusters) != len(old_values):
        raise ValueError("expected %d changed values, found %d"
                         % (len(old_values), len(clusters)))
    remaining = list(old_values)
    for cl in clusters:
        base = None
        for off in range(cl[0] - 3, cl[0] + 1):
            if off < 0 or off + 4 > len(orig):
                continue
            o = struct.unpack_from("<i", orig, off)[0]
            n = struct.unpack_from("<i", new, off)[0]
            if o in remaining and n == target:
                base = off
                remaining.remove(o)
                break
        if base is None:
            raise ValueError("unexpected byte change at offset %d" % cl[0])
    return len(clusters)


# ------------------------------------------------------------ world discovery

def world_name(world_dir, oodle):
    meta = os.path.join(world_dir, "LevelMeta.sav")
    try:
        gvas_bytes, _ = read_save(meta, oodle)
        gvas = parse_gvas(gvas_bytes)
        return gvas.properties["SaveData"]["value"]["WorldName"]["value"]
    except Exception:
        return os.path.basename(world_dir)


def list_worlds(oodle):
    worlds = []
    if not os.path.isdir(SAVE_ROOT):
        return worlds
    try:
        accounts = sorted(os.listdir(SAVE_ROOT))
    except OSError:
        return worlds
    for account in accounts:
        account_dir = os.path.join(SAVE_ROOT, account)
        if not os.path.isdir(account_dir):
            continue
        try:
            world_ids = sorted(os.listdir(account_dir))
        except OSError:
            continue
        for wid in world_ids:
            level = os.path.join(account_dir, wid, "Level.sav")
            if os.path.isfile(level):
                worlds.append({
                    "level": level,
                    "name": world_name(os.path.dirname(level), oodle),
                    "mtime": os.path.getmtime(level),
                })
    worlds.sort(key=lambda w: w["mtime"], reverse=True)
    return worlds


def game_is_running():
    # the local dedicated server counts too, it overwrites the save on shutdown
    names = ("palworld-win64-shipping.exe",
             "palworld-wingdk-shipping.exe",
             "palserver-win64-shipping.exe",
             "palserver.exe")
    try:
        # /FO CSV: the default table format truncates long image names
        out = subprocess.run(["tasklist", "/FO", "CSV"],
                             capture_output=True, text=True, timeout=15).stdout.lower()
        return any(n in out for n in names)
    except Exception:
        return False


# ------------------------------------------------------------- game pass

WGS_GLOB = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Packages",
                        "PocketpairInc.Palworld*", "SystemAppData", "wgs")


def _read_utf16(f, chars=None):
    if chars is None:
        (n,) = struct.unpack("<i", f.read(4))
        if n < 0 or n > 4096:
            raise ValueError("bad string length in Xbox container data")
        raw = f.read(n * 2)
    else:
        raw = f.read(chars * 2)
    return raw.decode("utf-16-le").rstrip("\x00")


def _parse_wgs_dir(root):
    """Read the Xbox save store index in root and return
    {save_path, blob} entries for every stored save file. Read only."""
    entries = []
    with open(os.path.join(root, "containers.index"), "rb") as f:
        f.read(4)
        (count,) = struct.unpack("<i", f.read(4))
        if count < 0 or count > 100000:
            raise ValueError("bad container count in containers.index")
        _read_utf16(f)          # package display name
        _read_utf16(f)          # store package name
        f.read(8)               # creation time
        f.read(4)
        _read_utf16(f)
        f.read(8)
        for _ in range(count):
            name = _read_utf16(f)
            _read_utf16(f)      # duplicate of the name
            _read_utf16(f)      # hex text
            (num,) = struct.unpack("B", f.read(1))
            f.read(4)
            folder = uuid.UUID(bytes_le=f.read(16))
            f.read(8)           # container time
            f.read(16)
            cdir = os.path.join(root, folder.hex.upper())
            cfile = os.path.join(cdir, "container.%d" % num)
            if not os.path.isfile(cfile):
                continue
            with open(cfile, "rb") as cf:
                cf.read(4)
                (fcount,) = struct.unpack("<i", cf.read(4))
                if fcount < 0 or fcount > 100000:
                    raise ValueError("bad file count in a container file")
                for _ in range(fcount):
                    _read_utf16(cf, 64)     # stored file name
                    g1 = uuid.UUID(bytes_le=cf.read(16))
                    g2 = uuid.UUID(bytes_le=cf.read(16))
                    blobs = [os.path.join(cdir, g.hex.upper())
                             for g in (g1, g2)]
                    blobs = [b for b in blobs if os.path.isfile(b)]
                    if not blobs:
                        continue
                    # when both generations exist take the newest one
                    blob = max(blobs, key=os.path.getmtime)
                    entries.append({
                        "save_path": name.replace("-", "/") + ".sav",
                        "blob": blob,
                    })
    return entries


def gamepass_extract(outdir):
    """Copy every Palworld save file out of the Game Pass save store into
    outdir with normal folder names. Never writes to the store itself."""
    roots = []
    for wgs in glob.glob(WGS_GLOB):
        try:
            subs = os.listdir(wgs)
        except OSError:
            continue
        for sub in subs:
            if os.path.isfile(os.path.join(wgs, sub, "containers.index")):
                roots.append(os.path.join(wgs, sub))
    if not roots:
        say("No Game Pass Palworld save store was found on this PC.")
        return False
    entries = []
    for root in roots:
        try:
            entries.extend(_parse_wgs_dir(root))
        except Exception as e:
            say("  Could not read %s: %s" % (root, short_error(e)))
    if not entries:
        say("The Game Pass save store was found but no save files were in it.")
        return False
    os.makedirs(outdir, exist_ok=True)
    copied = 0
    for e in entries:
        dest = os.path.join(outdir, e["save_path"].replace("/", os.sep))
        os.makedirs(os.path.dirname(dest) or outdir, exist_ok=True)
        shutil.copy2(e["blob"], dest)
        copied += 1
    say("Extracted %d save file(s) to %s" % (copied, outdir))
    say("")
    say("These are copies. The Game Pass originals were not touched. This")
    say("tool will not write into the Xbox save store, that is not safe and")
    say("could make the game or cloud sync reject the whole save. Fix a")
    say("copied Level.sav with option P, then use it on a Steam install or")
    say("a dedicated server.")
    return True


# --------------------------------------------------------------------- fix

def parse_slots(text):
    """A chest size the tool will accept, or None. 444 is the size the mod
    uses and the largest tested, 54 is the vanilla size."""
    try:
        n = int(str(text).strip())
    except ValueError:
        return None
    if 54 <= n <= 444:
        return n
    return None


def fix_save(level_path, oodle, assume_yes=False, target=TARGET_SLOTS):
    say("")
    say("Reading %s" % level_path)
    orig_gvas, fmt = read_save(level_path, oodle)
    gvas = parse_gvas(orig_gvas)
    wsd = gvas.properties["worldSaveData"]["value"]

    chests, notes = find_guild_chests(wsd)
    for n in notes:
        say("  " + n)
    if not chests:
        say("  No guild chests found in this save. Nothing to do.")
        return False

    to_change = [c for c in chests if c["slot_num"] < target]
    say("  Guild chests found: %d" % len(chests))
    for c in chests:
        status = ("grows to %d" % target if c["slot_num"] < target
                  else "already %d or more, left alone" % target)
        say("    Guild %s: %d slots (%d in use)  %s"
            % (c["guild_id"], c["slot_num"], c["filled"], status))
    if not to_change:
        say("  Every guild chest is already at %d slots or more. Nothing to do."
            % target)
        return False

    if not assume_yes:
        a = ask("\nApply the change? [Y/n] ").strip().lower()
        if a not in ("", "y", "yes"):
            say("Cancelled. Nothing was changed.")
            return False

    old_values = []
    for c in to_change:
        old_values.append(c["slot_num"])
        c["entry"]["value"]["SlotNum"]["value"] = target

    with contextlib.redirect_stdout(io.StringIO()):
        new_gvas = gvas.write({})
    changed = verify_diff(orig_gvas, new_gvas, old_values, target)
    say("  Verified: exactly %d chest size value(s) changed, nothing else." % changed)

    # write to a sibling temp file, prove it reads back correctly, then swap in
    tmp = level_path + ".gcfix_new"
    try:
        write_save(tmp, new_gvas, fmt, oodle)
        reread_gvas, _ = read_save(tmp, oodle)
        if reread_gvas != new_gvas:
            raise ValueError("recompression check failed, the file was NOT replaced")
        reparsed, _ = find_guild_chests(parse_gvas(reread_gvas).properties["worldSaveData"]["value"])
        by_id = {c["guild_id"]: c for c in reparsed}
        for c in to_change:
            after = by_id.get(c["guild_id"])
            if after is None or after["slot_num"] != target or after["filled"] != c["filled"]:
                raise ValueError("read back check failed for guild %s, the file was NOT replaced"
                                 % c["guild_id"])

        stamp = time.strftime("%Y%m%d_%H%M%S")
        backup = level_path + ".gcfix_backup_" + stamp
        shutil.copy2(level_path, backup)
        os.replace(tmp, level_path)
    except Exception:
        # never leave a half made temp file behind
        if os.path.isfile(tmp):
            try:
                os.remove(tmp)
            except OSError:
                pass
        raise
    say("")
    say("Done. %d guild chest(s) expanded to %d slots. All stored items kept."
        % (len(to_change), target))
    say("Backup of the untouched save: %s" % backup)
    say("If anything ever looks wrong, delete Level.sav and rename that backup back.")
    return True


# --------------------------------------------------------------------- main

def main():
    say("=" * 62)
    say(" Guild Chest Fix %s" % VERSION)
    say(" Companion tool for the Guild Storage Expander mod")
    say("=" * 62)
    say("")
    say("Expands the Guild Chest of guilds that already existed before the")
    say("mod was installed, to the mod's %d slots. New guilds do not need" % TARGET_SLOTS)
    say("this. You can also pick a smaller size if you prefer a lighter")
    say("boost. It never shrinks a chest and never touches your items, and")
    say("it keeps a backup of the save it edits.")
    say("")

    args = [a for a in sys.argv[1:] if a != "--yes"]
    assume_yes = "--yes" in sys.argv[1:]

    slots = TARGET_SLOTS
    slots_given = False
    if "--slots" in args:
        i = args.index("--slots")
        value = parse_slots(args[i + 1]) if i + 1 < len(args) else None
        if value is None:
            say("--slots needs a whole number from 54 to 444 after it.")
            pause_exit(1)
        slots = value
        slots_given = True
        del args[i:i + 2]

    if args and args[0].lower() == "--gamepass":
        outdir = args[1] if len(args) > 1 else os.path.join(
            os.path.expanduser("~"), "Desktop", "PalworldGamePassSaves")
        gamepass_extract(outdir)
        pause_exit(0)

    while game_is_running():
        say("Palworld or its dedicated server is running on this PC. Close the")
        say("game and stop the server first. Saves edited while they run get")
        say("overwritten or corrupted.")
        if assume_yes:
            sys.exit(1)
        ask("Press Enter once the game is closed. ")

    oodle = get_oodle()

    if args:
        path_arg = args[0].strip().strip('"')
        if not os.path.isfile(path_arg):
            say("No file at %s" % path_arg)
            pause_exit(1)
        fix_save(path_arg, oodle, assume_yes, slots)
        pause_exit(0)

    if not slots_given:
        say("")
        while True:
            raw = ask("Chest size to set, from 54 to 444, press Enter for %d: "
                      % TARGET_SLOTS).strip()
            if not raw:
                break
            n = parse_slots(raw)
            if n is not None:
                slots = n
                break
            say("Please give a whole number from 54 to 444.")

    worlds = list_worlds(oodle)
    while True:
        say("")
        if worlds:
            say("Found these worlds on this PC:")
            say("")
            for i, w in enumerate(worlds, 1):
                say("  %d. %-32s (last played %s)"
                    % (i, w["name"], time.strftime("%Y-%m-%d", time.localtime(w["mtime"]))))
        else:
            say("No local Palworld worlds found under %s" % SAVE_ROOT)
        say("")
        say("  P. Enter a path to a Level.sav by hand (dedicated servers)")
        say("  G. Copy Game Pass saves out of the Xbox save store (read only)")
        say("  Q. Quit")
        choice = ask("\nPick an option: ").strip().lower()
        if choice == "q":
            break
        if choice == "g":
            default = os.path.join(os.path.expanduser("~"), "Desktop",
                                   "PalworldGamePassSaves")
            p = ask("Folder to copy them into (Enter for %s): " % default).strip().strip('"')
            gamepass_extract(p or default)
            continue
        if choice == "p":
            say("For a dedicated server save, stop the server before copying the")
            say("file and keep it stopped until the fixed file is uploaded back.")
            p = ask("Full path to Level.sav: ").strip().strip('"')
            if os.path.isfile(p):
                fix_save(p, oodle, target=slots)
            else:
                say("No file at that path.")
            continue
        if choice.isdigit() and 1 <= int(choice) <= len(worlds):
            fix_save(worlds[int(choice) - 1]["level"], oodle, target=slots)
            continue
        say("Not an option.")
    pause_exit(0)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except KeyboardInterrupt:
        say("\nCancelled. Nothing was changed unless a 'Done.' message was printed.")
        sys.exit(1)
    except Exception as e:
        say("")
        say("ERROR: %s" % short_error(e))
        say("The save file was NOT replaced unless a 'Done.' message was printed.")
        pause_exit(1)
