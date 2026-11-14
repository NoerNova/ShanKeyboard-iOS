#!/usr/bin/env python3
"""Build Shan/Autocomplete/Resource/ngram_model.bin from bigram_data.json.

Flat little-endian binary the keyboard extension mmaps read-only and reads
in place (NGramService.MappedNGramModel). Nothing is copied into Swift arrays
or dictionaries, so the model adds no dirty memory to the extension: its pages
are clean and file-backed, which iOS does not count toward the Jetsam limit.

Layout (keep in sync with NGramService.MappedNGramModel):
  magic  u32 = "SNGM"  | version u32 = 2 | n u32 | blobLen u32
  vocabOffsets u32[n+1] | utf8 blob      | unigram f32[n]
  m u32 | bigramOffsets i32[n+1] | bigramIdx i32[m] | bigramCnt u16[m]
  t u32 | triKey i64[t] (sorted)  | triIdx i32[t]   | triCnt u16[t]
  sortedIdx u32[n]   vocab indices ordered by UTF-8 bytes, ties by index

v2 adds sortedIdx. UTF-8 byte order equals Unicode scalar order, so it serves
both exact word lookup and scalar-level prefix search by binary search.

Usage:
  python3 Scripts/build_ngram_bin.py            # build
  python3 Scripts/build_ngram_bin.py --verify   # build, then re-read the bin
                                                # and assert it round-trips
                                                # against the JSON source
"""
import json
import os
import struct
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC = os.path.join(ROOT, "Shan", "Autocomplete", "Resource", "bigram_data.json")
DST = os.path.join(ROOT, "Shan", "Autocomplete", "Resource", "ngram_model.bin")
MAGIC = 0x4D474E53  # "SNGM" little-endian
VERSION = 2
CLAMP = 0xFFFF  # counts stored as u16, same clamp as the Swift plist parser


def load_source():
    with open(SRC) as f:
        d = json.load(f)
    n = len(d["vocab"])
    assert len(d["unigram_log_probs"]) == n
    # Mirror the Swift parser: drop bigrams with out-of-range context.
    bigrams = sorted(
        (c, fol, min(cnt, CLAMP)) for c, fol, cnt in d["bigrams"] if c < n
    )
    trigrams = sorted(
        ((c1 << 32) | c2, fol, min(cnt, CLAMP)) for c1, c2, fol, cnt in d["trigrams"]
    )
    return d, bigrams, trigrams


def sorted_index(vocab):
    return sorted(range(len(vocab)), key=lambda i: (vocab[i].encode("utf-8"), i))


def build():
    d, bigrams, trigrams = load_source()
    vocab, uni = d["vocab"], d["unigram_log_probs"]
    n, m, t = len(vocab), len(bigrams), len(trigrams)

    parts = [w.encode("utf-8") for w in vocab]
    offsets = [0]
    for p in parts:
        offsets.append(offsets[-1] + len(p))
    blob = b"".join(parts)

    row = [0] * (n + 1)
    for c, _, _ in bigrams:
        row[c + 1] += 1
    for i in range(1, n + 1):
        row[i] += row[i - 1]

    with open(DST, "wb") as f:
        f.write(struct.pack("<IIII", MAGIC, VERSION, n, len(blob)))
        f.write(struct.pack(f"<{n + 1}I", *offsets))
        f.write(blob)
        f.write(struct.pack(f"<{n}f", *uni))
        f.write(struct.pack("<I", m))
        f.write(struct.pack(f"<{n + 1}i", *row))
        f.write(struct.pack(f"<{m}i", *(e[1] for e in bigrams)))
        f.write(struct.pack(f"<{m}H", *(e[2] for e in bigrams)))
        f.write(struct.pack("<I", t))
        f.write(struct.pack(f"<{t}q", *(e[0] for e in trigrams)))
        f.write(struct.pack(f"<{t}i", *(e[1] for e in trigrams)))
        f.write(struct.pack(f"<{t}H", *(e[2] for e in trigrams)))
        f.write(struct.pack(f"<{n}I", *sorted_index(vocab)))

    print(f"wrote {os.path.relpath(DST, ROOT)}: {os.path.getsize(DST):,} bytes "
          f"(vocab={n} bigrams={m} trigrams={t})")


def verify():
    d, bigrams, trigrams = load_source()
    data = open(DST, "rb").read()
    off = 0

    def read(fmt):
        nonlocal off
        size = struct.calcsize(fmt)
        vals = struct.unpack_from(fmt, data, off)
        off += size
        return vals

    magic, version, n, blob_len = read("<IIII")
    assert magic == MAGIC and version == VERSION
    assert n == len(d["vocab"])

    offsets = read(f"<{n + 1}I")
    blob = data[off:off + blob_len]
    off += blob_len
    vocab = [blob[offsets[i]:offsets[i + 1]].decode("utf-8") for i in range(n)]
    assert vocab == d["vocab"], "vocab mismatch"

    uni = read(f"<{n}f")
    for got, want in zip(uni, d["unigram_log_probs"]):
        f32 = struct.unpack("<f", struct.pack("<f", want))[0]
        assert got == f32, f"unigram mismatch: {got} != {f32}"

    (m,) = read("<I")
    row = read(f"<{n + 1}i")
    b_idx = read(f"<{m}i")
    b_cnt = read(f"<{m}H")
    got_bigrams = []
    for c in range(n):
        for j in range(row[c], row[c + 1]):
            got_bigrams.append((c, b_idx[j], b_cnt[j]))
    assert sorted(got_bigrams) == bigrams, "bigram CSR mismatch"

    (t,) = read("<I")
    t_key = read(f"<{t}q")
    t_idx = read(f"<{t}i")
    t_cnt = read(f"<{t}H")
    assert sorted(zip(t_key, t_idx, t_cnt)) == trigrams, "trigram mismatch"
    assert list(t_key) == sorted(t_key), "trigram keys not sorted"

    s_idx = read(f"<{n}I")
    assert list(s_idx) == sorted_index(vocab), "sorted index mismatch"

    assert off == len(data), f"trailing bytes: {len(data) - off}"
    print(f"verify OK: {n} vocab, {m} bigrams, {t} trigrams round-trip exactly")


if __name__ == "__main__":
    build()
    if "--verify" in sys.argv:
        verify()
