//
//  MappedLexicon.swift
//  ShanKeyboard
//
//  Read-only, memory-mapped word data for the keyboard extension.
//
//  Why: keyboard extensions are killed (Jetsam) when their phys_footprint
//  crosses a per-process cap, and iOS then falls back to the English keyboard.
//  The old TrieNode dictionary held ~180k heap nodes, and building it decoded
//  the whole plist into Swift objects first. A read-only file mapping is clean,
//  file-backed memory: it does not count toward phys_footprint, there is no
//  decode peak, and the kernel can drop its pages under pressure and fault them
//  back in on the next lookup.
//

import Darwin
import Foundation

// MARK: - MappedFile

/// A whole file mapped PROT_READ. The pointer stays valid until deinit.
final class MappedFile {
    let bytes: UnsafeRawBufferPointer

    init?(url: URL) {
        let fd = open(url.path, O_RDONLY)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var info = stat()
        guard fstat(fd, &info) == 0, info.st_size > 0 else { return nil }
        let size = Int(info.st_size)

        guard let base = mmap(nil, size, PROT_READ, MAP_PRIVATE, fd, 0),
              base != MAP_FAILED else { return nil }
        bytes = UnsafeRawBufferPointer(start: base, count: size)
    }

    deinit {
        munmap(UnsafeMutableRawPointer(mutating: bytes.baseAddress), bytes.count)
    }

    /// Finds a bundled resource in the main bundle or the extension's bundle.
    static func resource(_ name: String, _ ext: String, for cls: AnyClass) -> MappedFile? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext)
                     ?? Bundle(for: cls).url(forResource: name, withExtension: ext)
        else { return nil }
        return MappedFile(url: url)
    }
}

// MARK: - BinaryReader

/// Bounds-checked sequential reader used only while parsing a file header.
/// Every read is unaligned-safe, so section offsets need no alignment.
struct BinaryReader {
    let bytes: UnsafeRawBufferPointer
    private(set) var offset = 0

    init(_ bytes: UnsafeRawBufferPointer) { self.bytes = bytes }

    mutating func u32() -> UInt32? {
        guard offset + 4 <= bytes.count else { return nil }
        defer { offset += 4 }
        return UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }

    /// Reserves `count` elements of `stride` bytes and returns their start offset.
    mutating func section(count: Int, stride: Int) -> Int? {
        let length = count.multipliedReportingOverflow(by: stride)
        guard count >= 0, !length.overflow, offset + length.partialValue <= bytes.count else { return nil }
        defer { offset += length.partialValue }
        return offset
    }

    mutating func align(to boundary: Int) {
        offset += (boundary - offset % boundary) % boundary
    }
}

extension UnsafeRawBufferPointer {
    @inline(__always)
    func u32(at offset: Int) -> UInt32 {
        UInt32(littleEndian: loadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }
}

/// Lexicographic comparison of raw UTF-8 bytes (equal to Unicode scalar order).
@inline(__always)
func compareBytes(_ a: UnsafeRawBufferPointer, _ b: UnsafeRawBufferPointer) -> Int {
    let n = Swift.min(a.count, b.count)
    if n > 0 {
        let r = memcmp(a.baseAddress!, b.baseAddress!, n)
        if r != 0 { return Int(r) }
    }
    return a.count - b.count
}

/// True when `text` starts with `prefix`, byte-wise (scalar-level prefix).
@inline(__always)
func bytesHavePrefix(_ text: UnsafeRawBufferPointer, _ prefix: UnsafeRawBufferPointer) -> Bool {
    guard text.count >= prefix.count else { return false }
    return prefix.isEmpty || memcmp(text.baseAddress!, prefix.baseAddress!, prefix.count) == 0
}

/// Runs `body` with the string's UTF-8 bytes, without copying when possible.
@inline(__always)
func withUTF8Bytes<R>(_ string: String, _ body: (UnsafeRawBufferPointer) -> R) -> R {
    var s = string
    return s.withUTF8 { body(UnsafeRawBufferPointer($0)) }
}

// MARK: - MappedStringTable

/// One sorted table of the lexicon file: UTF-8 strings plus a u32 frequency each.
struct MappedStringTable {
    private let bytes: UnsafeRawBufferPointer
    let count: Int
    private let offsetsAt: Int
    private let freqAt: Int
    private let blobAt: Int
    private let blobLength: Int

    /// Layout: count u32 | blobLen u32 | offsets u32[count+1] | freq u32[count] | blob | pad4
    init?(reader: inout BinaryReader) {
        guard let count = reader.u32().map(Int.init),
              let blobLength = reader.u32().map(Int.init),
              let offsetsAt = reader.section(count: count + 1, stride: 4),
              let freqAt = reader.section(count: count, stride: 4),
              let blobAt = reader.section(count: blobLength, stride: 1)
        else { return nil }
        reader.align(to: 4)

        self.bytes = reader.bytes
        self.count = count
        self.offsetsAt = offsetsAt
        self.freqAt = freqAt
        self.blobAt = blobAt
        self.blobLength = blobLength

        // Validate every string range once, so lookups need no checks.
        var previous: UInt32 = 0
        for i in 0...count {
            let o = bytes.u32(at: offsetsAt + i * 4)
            guard o >= previous, Int(o) <= blobLength else { return nil }
            previous = o
        }
    }

    @inline(__always)
    func entryBytes(_ i: Int) -> UnsafeRawBufferPointer {
        let start = Int(bytes.u32(at: offsetsAt + i * 4))
        let end = Int(bytes.u32(at: offsetsAt + (i + 1) * 4))
        return UnsafeRawBufferPointer(rebasing: bytes[(blobAt + start)..<(blobAt + end)])
    }

    @inline(__always)
    func frequency(_ i: Int) -> Int { Int(bytes.u32(at: freqAt + i * 4)) }

    func string(_ i: Int) -> String {
        String(decoding: entryBytes(i), as: UTF8.self)
    }

    /// First index whose entry is >= key.
    func lowerBound(_ key: UnsafeRawBufferPointer) -> Int {
        var lo = 0, hi = count
        while lo < hi {
            let mid = (lo + hi) >> 1
            if compareBytes(entryBytes(mid), key) < 0 { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    /// Half-open index range of the entries starting with `prefix`.
    func prefixRange(_ prefix: UnsafeRawBufferPointer) -> Range<Int> {
        let lo = lowerBound(prefix)
        guard !prefix.isEmpty else { return lo..<count }
        var hi = lo
        var step = 1
        // Gallop forward, then binary search the boundary: short prefixes can
        // cover thousands of entries, long ones usually only a handful.
        while hi < count, bytesHavePrefix(entryBytes(hi), prefix) {
            hi = Swift.min(count, hi + step)
            step <<= 1
        }
        var left = lo, right = hi
        while left < right {
            let mid = (left + right) >> 1
            if bytesHavePrefix(entryBytes(mid), prefix) { left = mid + 1 } else { right = mid }
        }
        return lo..<left
    }

    func contains(_ key: UnsafeRawBufferPointer) -> Bool {
        let i = lowerBound(key)
        return i < count && compareBytes(entryBytes(i), key) == 0
    }

    /// The `limit` most frequent entries starting with `prefix`, frequency descending.
    func topMatches(prefix: String, limit: Int) -> [(word: String, frequency: Int)] {
        guard limit > 0 else { return [] }
        let range = withUTF8Bytes(prefix) { prefixRange($0) }

        // Small insertion-sorted buffer: limit is <= 10 at every call site.
        var best: [(index: Int, frequency: Int)] = []
        best.reserveCapacity(limit + 1)
        for i in range {
            let f = frequency(i)
            if best.count == limit, let last = best.last, f <= last.frequency { continue }
            var pos = best.count
            while pos > 0 && best[pos - 1].frequency < f { pos -= 1 }
            best.insert((i, f), at: pos)
            if best.count > limit { best.removeLast() }
        }
        return best.map { (string($0.index), $0.frequency) }
    }
}

// MARK: - MappedLexicon

/// The bundled dictionary (`lexicon.bin`, built by Scripts/build_lexicon_bin.py).
final class MappedLexicon {
    private let file: MappedFile
    let words: MappedStringTable
    let syllables: MappedStringTable
    /// The 100 most frequent words, most frequent first.
    let topWords: [String]
    /// Longest word length in grapheme clusters, for Tokenizer's maximal matching.
    let maxWordLength: Int

    /// Must run off the main thread: maxWordLength touches every word once.
    init?(file: MappedFile) {
        var reader = BinaryReader(file.bytes)
        guard reader.u32() == 0x5845_4C53, reader.u32() == 1,
              let words = MappedStringTable(reader: &reader),
              let syllables = MappedStringTable(reader: &reader),
              let topCount = reader.u32().map(Int.init),
              let topAt = reader.section(count: topCount, stride: 4)
        else { return nil }

        var top: [String] = []
        top.reserveCapacity(topCount)
        for i in 0..<topCount {
            let idx = Int(file.bytes.u32(at: topAt + i * 4))
            guard idx < words.count else { return nil }
            top.append(words.string(idx))
        }

        var maxLength = 0
        for i in 0..<words.count {
            maxLength = max(maxLength, words.string(i).count)
        }

        self.file = file
        self.words = words
        self.syllables = syllables
        self.topWords = top
        self.maxWordLength = maxLength
    }

    func containsWord(_ text: String) -> Bool {
        withUTF8Bytes(text) { words.contains($0) }
    }

    func containsSyllable(_ text: String) -> Bool {
        withUTF8Bytes(text) { syllables.contains($0) }
    }

    /// Scalar-level prefix check: "ၵုမ" is a prefix of "ၵုမ်".
    func isWordPrefix(_ prefix: String) -> Bool {
        withUTF8Bytes(prefix) { key in
            let i = words.lowerBound(key)
            return i < words.count && bytesHavePrefix(words.entryBytes(i), key)
        }
    }
}
