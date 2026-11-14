#!/usr/bin/env python3
"""Build Shan/Autocomplete/Resource/lexicon.bin from filtered_frequency_data.json.

The keyboard extension mmaps this file read-only and searches it in place
(MappedLexicon.swift). Nothing is decoded into Swift objects, so the dictionary
costs no dirty memory: its pages are clean and file-backed, which iOS does not
count toward the extension's Jetsam limit and can drop under pressure.

Entries are sorted by raw UTF-8 bytes. UTF-8 byte order equals Unicode scalar
order, so every word sharing a scalar prefix is one contiguous run. That keeps
the scalar-level prefix semantics the old TrieNode had (incomplete Shan words
like "ၵုမ" still match "ၵုမ်").

Layout (little-endian, keep in sync with MappedLexicon.swift):
  magic u32 = "SLEX" | version u32 = 1
  words table, then syllables table, each:
    count u32 | blobLen u32 | offsets u32[count+1] | freq u32[count]
    | utf8 blob[blobLen] | zero padding to a 4-byte boundary
  topCount u32 | topIdx u32[topCount]   (word indices, frequency descending)

Duplicate entries keep their highest frequency, matching TrieNode.insert.

Usage:
  python3 -I Scripts/build_lexicon_bin.py            # build
  python3 -I Scripts/build_lexicon_bin.py --verify   # build, re-read, assert
"""
import json
import os
import struct
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC = os.path.join(ROOT, "Shan", "Autocomplete", "Resource", "filtered_frequency_data.json")
DST = os.path.join(ROOT, "Shan", "Autocomplete", "Resource", "lexicon.bin")
MAGIC = 0x58454C53  # "SLEX" little-endian
VERSION = 1
TOP_COUNT = 100
U32_MAX = 0xFFFFFFFF


def dedupe(pairs):
    best = {}
    for text, freq in pairs:
        if not text:
            continue
        freq = max(0, min(int(freq), U32_MAX))
        if freq > best.get(text, -1):
            best[text] = freq
    return sorted(best.items(), key=lambda kv: kv[0].encode("utf-8"))


def load_source():
    with open(SRC, encoding="utf-8") as f:
        d = json.load(f)
    words = dedupe((w["word"], w["frequency"]) for w in d["words"])
    syllables = dedupe((s["syllable"], s["frequency"]) for s in d["syllables"])
    # Highest frequency first; ties keep sorted (byte) order.
    order = sorted(range(len(words)), key=lambda i: -words[i][1])
    return words, syllables, order[:TOP_COUNT]


def table_bytes(entries):
    parts = [t.encode("utf-8") for t, _ in entries]
    offsets = [0]
    for p in parts:
        offsets.append(offsets[-1] + len(p))
    blob = b"".join(parts)
    n = len(entries)
    out = struct.pack("<II", n, len(blob))
    out += struct.pack(f"<{n + 1}I", *offsets)
    out += struct.pack(f"<{n}I", *(f for _, f in entries))
    out += blob
    out += b"\0" * (-len(out) % 4)
    return out


def build():
    words, syllables, top = load_source()
    with open(DST, "wb") as f:
        f.write(struct.pack("<II", MAGIC, VERSION))
        f.write(table_bytes(words))
        f.write(table_bytes(syllables))
        f.write(struct.pack("<I", len(top)))
        f.write(struct.pack(f"<{len(top)}I", *top))
    print(f"wrote {os.path.relpath(DST, ROOT)}: {os.path.getsize(DST):,} bytes "
          f"(words={len(words)} syllables={len(syllables)} top={len(top)})")


def verify():
    words, syllables, top = load_source()
    data = open(DST, "rb").read()
    off = 0

    def read(fmt):
        nonlocal off
        vals = struct.unpack_from(fmt, data, off)
        off += struct.calcsize(fmt)
        return vals

    def read_table():
        nonlocal off
        n, blob_len = read("<II")
        offsets = read(f"<{n + 1}I")
        freqs = read(f"<{n}I")
        blob = data[off:off + blob_len]
        off += blob_len
        off += -off % 4
        texts = [blob[offsets[i]:offsets[i + 1]].decode("utf-8") for i in range(n)]
        return list(zip(texts, freqs))

    magic, version = read("<II")
    assert magic == MAGIC and version == VERSION
    got_words = read_table()
    got_syllables = read_table()
    (top_n,) = read("<I")
    got_top = list(read(f"<{top_n}I"))
    assert got_words == words, "words mismatch"
    assert got_syllables == syllables, "syllables mismatch"
    assert got_top == top, "top mismatch"
    keys = [w.encode("utf-8") for w, _ in got_words]
    assert keys == sorted(keys) and len(set(keys)) == len(keys), "words not sorted/unique"
    assert off == len(data), f"trailing bytes: {len(data) - off}"
    print(f"verify OK: {len(words)} words, {len(syllables)} syllables, {top_n} top")


if __name__ == "__main__":
    build()
    if "--verify" in sys.argv:
        verify()
