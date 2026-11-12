//
//  NGramService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 16/3/2569 BE.
//

import Foundation

// MARK: - Model

/// Zero-copy view of ngram_model.bin (built by Scripts/build_ngram_bin.py).
///
/// Every table is read in place from a read-only file mapping. Nothing is
/// copied into Swift arrays or dictionaries, so the model adds no dirty memory
/// to the extension and has no load peak. The old loader built ~29k Strings, a
/// [String: Int] index and ~20k heap arrays for the trigram table, which was the
/// largest resident block after the dictionary trie.
///
/// Layout (little-endian, v2):
///   magic u32 "SNGM" | version u32 = 2 | n u32 | blobLen u32
///   vocabOffsets u32[n+1] | utf8 blob | unigram f32[n]
///   m u32 | bigramOffsets i32[n+1] | bigramIdx i32[m] | bigramCnt u16[m]
///   t u32 | triKey i64[t] (sorted) | triIdx i32[t] | triCnt u16[t]
///   sortedIdx u32[n]  (vocab indices in UTF-8 byte order, ties by index)
private final class MappedNGramModel {
    private let file: MappedFile
    private let bytes: UnsafeRawBufferPointer

    let vocabSize: Int
    private let vocabOffsetsAt: Int
    private let blobAt: Int
    private let unigramAt: Int
    private let bigramCount: Int
    private let bigramOffsetsAt: Int
    private let bigramIdxAt: Int
    private let bigramCntAt: Int
    private let trigramCount: Int
    private let triKeyAt: Int
    private let triIdxAt: Int
    private let triCntAt: Int
    private let sortedAt: Int

    init?(file: MappedFile) {
        let bytes = file.bytes
        var r = BinaryReader(bytes)
        guard r.u32() == 0x4D47_4E53, r.u32() == 2,
              let n = r.u32().map(Int.init),
              let blobLen = r.u32().map(Int.init),
              let vocabOffsetsAt = r.section(count: n + 1, stride: 4),
              let blobAt = r.section(count: blobLen, stride: 1),
              let unigramAt = r.section(count: n, stride: 4),
              let m = r.u32().map(Int.init),
              let bigramOffsetsAt = r.section(count: n + 1, stride: 4),
              let bigramIdxAt = r.section(count: m, stride: 4),
              let bigramCntAt = r.section(count: m, stride: 2),
              let t = r.u32().map(Int.init),
              let triKeyAt = r.section(count: t, stride: 8),
              let triIdxAt = r.section(count: t, stride: 4),
              let triCntAt = r.section(count: t, stride: 2),
              let sortedAt = r.section(count: n, stride: 4)
        else { return nil }

        // Validate once so lookups can index without checks.
        var previous: UInt32 = 0
        for i in 0...n {
            let o = bytes.u32(at: vocabOffsetsAt + i * 4)
            guard o >= previous, Int(o) <= blobLen else { return nil }
            previous = o
        }
        var previousRow: Int32 = 0
        for i in 0...n {
            let o = Int32(littleEndian: bytes.loadUnaligned(fromByteOffset: bigramOffsetsAt + i * 4, as: Int32.self))
            guard o >= previousRow, Int(o) <= m else { return nil }
            previousRow = o
        }
        for i in 0..<m {
            let idx = Int32(littleEndian: bytes.loadUnaligned(fromByteOffset: bigramIdxAt + i * 4, as: Int32.self))
            guard idx >= 0, Int(idx) < n else { return nil }
        }
        for i in 0..<t {
            let idx = Int32(littleEndian: bytes.loadUnaligned(fromByteOffset: triIdxAt + i * 4, as: Int32.self))
            guard idx >= 0, Int(idx) < n else { return nil }
        }
        for i in 0..<n where Int(bytes.u32(at: sortedAt + i * 4)) >= n { return nil }

        self.file = file
        self.bytes = bytes
        self.vocabSize = n
        self.vocabOffsetsAt = vocabOffsetsAt
        self.blobAt = blobAt
        self.unigramAt = unigramAt
        self.bigramCount = m
        self.bigramOffsetsAt = bigramOffsetsAt
        self.bigramIdxAt = bigramIdxAt
        self.bigramCntAt = bigramCntAt
        self.trigramCount = t
        self.triKeyAt = triKeyAt
        self.triIdxAt = triIdxAt
        self.triCntAt = triCntAt
        self.sortedAt = sortedAt
    }

    // MARK: Vocab

    @inline(__always)
    private func wordBytes(_ i: Int) -> UnsafeRawBufferPointer {
        let s = Int(bytes.u32(at: vocabOffsetsAt + i * 4))
        let e = Int(bytes.u32(at: vocabOffsetsAt + (i + 1) * 4))
        return UnsafeRawBufferPointer(rebasing: bytes[(blobAt + s)..<(blobAt + e)])
    }

    func word(_ i: Int) -> String {
        String(decoding: wordBytes(i), as: UTF8.self)
    }

    @inline(__always)
    private func sorted(_ k: Int) -> Int { Int(bytes.u32(at: sortedAt + k * 4)) }

    /// First position in sortedIdx whose word is >= key.
    private func lowerBound(_ key: UnsafeRawBufferPointer) -> Int {
        var lo = 0, hi = vocabSize
        while lo < hi {
            let mid = (lo + hi) >> 1
            if compareBytes(wordBytes(sorted(mid)), key) < 0 { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    /// Vocab index of `word`; the first occurrence if the vocab has duplicates.
    func index(of word: String) -> Int? {
        withUTF8Bytes(word) { key in
            let k = lowerBound(key)
            guard k < vocabSize else { return nil }
            let idx = sorted(k)
            return compareBytes(wordBytes(idx), key) == 0 ? idx : nil
        }
    }

    /// Vocab indices whose words start with `prefix` at scalar level (byte-wise
    /// on UTF-8). Grapheme-level hasPrefix fails for Shan combining marks, e.g.
    /// "မႂ်ႇမႂ်ႇ".hasPrefix("မႂ်ႇ") is false at grapheme level.
    func indices(withPrefix prefix: String) -> [Int] {
        withUTF8Bytes(prefix) { key in
            var out = [Int]()
            var k = lowerBound(key)
            while k < vocabSize {
                let idx = sorted(k)
                guard bytesHavePrefix(wordBytes(idx), key) else { break }
                out.append(idx)
                k += 1
            }
            return out
        }
    }

    @inline(__always)
    func unigramLogProb(_ i: Int) -> Float {
        Float(bitPattern: bytes.u32(at: unigramAt + i * 4))
    }

    // MARK: Bigrams (CSR)

    func bigramRange(context c: Int) -> Range<Int> {
        let s = Int(Int32(littleEndian: bytes.loadUnaligned(fromByteOffset: bigramOffsetsAt + c * 4, as: Int32.self)))
        let e = Int(Int32(littleEndian: bytes.loadUnaligned(fromByteOffset: bigramOffsetsAt + (c + 1) * 4, as: Int32.self)))
        return s..<e
    }

    @inline(__always)
    func bigramFollower(_ j: Int) -> (idx: Int, count: Int) {
        let idx = Int32(littleEndian: bytes.loadUnaligned(fromByteOffset: bigramIdxAt + j * 4, as: Int32.self))
        let cnt = UInt16(littleEndian: bytes.loadUnaligned(fromByteOffset: bigramCntAt + j * 2, as: UInt16.self))
        return (Int(idx), Int(cnt))
    }

    // MARK: Trigrams (sorted keys, binary search)

    @inline(__always)
    private func triKey(_ j: Int) -> Int64 {
        Int64(littleEndian: bytes.loadUnaligned(fromByteOffset: triKeyAt + j * 8, as: Int64.self))
    }

    /// Entries for context (c1, c2); empty when the pair was never seen.
    func trigramRange(_ c1: Int, _ c2: Int) -> Range<Int> {
        let key = Int64(c1) << 32 | Int64(c2)
        var lo = 0, hi = trigramCount
        while lo < hi {
            let mid = (lo + hi) >> 1
            if triKey(mid) < key { lo = mid + 1 } else { hi = mid }
        }
        var end = lo
        while end < trigramCount && triKey(end) == key { end += 1 }
        return lo..<end
    }

    @inline(__always)
    func trigramFollower(_ j: Int) -> (idx: Int, count: Int) {
        let idx = Int32(littleEndian: bytes.loadUnaligned(fromByteOffset: triIdxAt + j * 4, as: Int32.self))
        let cnt = UInt16(littleEndian: bytes.loadUnaligned(fromByteOffset: triCntAt + j * 2, as: UInt16.self))
        return (Int(idx), Int(cnt))
    }
}

// MARK: - NGramService

class NGramService {

    // Interpolation weights (must sum to 1.0)
    private struct Weights {
        var trigram: Float  = 0.40
        var bigram: Float   = 0.35
        var unigram: Float  = 0.15
        var userBigram: Float = 0.10
    }

    private(set) var isLoaded = false
    private var model: MappedNGramModel?

    // MARK: - Async Loading

    /// Maps the model on a background queue. Mapping costs no dirty memory, so
    /// every device loads it, including low-RAM ones that used to skip it.
    /// The plist/JSON fallback is gone on purpose: its Foundation parse peak
    /// was what got the extension killed. If ngram_model.bin is missing or
    /// corrupt, isLoaded stays false and suggestions use the personal bigram path.
    func loadAsync(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let model = MappedFile.resource("ngram_model", "bin", for: NGramService.self)
                .flatMap(MappedNGramModel.init(file:))
            DispatchQueue.main.async {
                guard let self else { return }
                self.model = model
                self.isLoaded = model != nil
                MemoryProbe.log("ngram loaded=\(model != nil)")
                completion?()
            }
        }
    }

    // MARK: - Scoring API

    /// Returns top candidate words scored by interpolated backoff.
    ///
    /// - Parameters:
    ///   - context: The 1–2 most recently completed words (newest last).
    ///   - partialNext: Prefix of the word being typed (may be empty for next-word suggestions).
    ///   - userBigramChain: The personal usage bigram chain from AutocompleteDataManager.
    ///   - limit: Maximum number of results to return.
    func scoredCandidates(
        context: [String],
        partialNext: String = "",
        userBigramChain: [String: [String: Int]] = [:],
        limit: Int = 10
    ) -> [(word: String, score: Float)] {

        guard let model else { return [] }

        // Resolve context word indices
        let ctx1Idx: Int? = context.count >= 2 ? model.index(of: context[context.count - 2]) : nil
        let ctx2Idx: Int? = context.last.flatMap { model.index(of: $0) }

        // Decide which candidates to score: vocab filtered by partialNext
        let candidates: [Int]
        if partialNext.isEmpty {
            // Use trigram/bigram followers as the candidate set for speed
            candidates = topCandidateIndices(ctx1: ctx1Idx, ctx2: ctx2Idx, model: model)
        } else {
            candidates = model.indices(withPrefix: partialNext)
        }

        // Per-context stats hoisted out of the candidate loop: follower
        // probabilities, totals, and backoff weight redistribution depend only
        // on the context, not the candidate.
        var baseW = Weights()

        var triProb = [Int: Float]()
        let triRange = (ctx1Idx != nil && ctx2Idx != nil) ? model.trigramRange(ctx1Idx!, ctx2Idx!) : 0..<0
        if !triRange.isEmpty {
            let total = Float(triRange.reduce(0) { $0 + model.trigramFollower($1).count })
            triProb.reserveCapacity(triRange.count)
            for j in triRange {
                let f = model.trigramFollower(j)
                triProb[f.idx] = Float(f.count) / total
            }
        } else {
            // Missing trigram context — redistribute λ₃
            baseW.bigram  += baseW.trigram * 0.70
            baseW.unigram += baseW.trigram * 0.30
            baseW.trigram  = 0
        }

        var biProb = [Int: Float]()
        if let c2 = ctx2Idx {
            let range = model.bigramRange(context: c2)
            if !range.isEmpty {
                let total = Float(range.reduce(0) { $0 + model.bigramFollower($1).count })
                biProb.reserveCapacity(range.count)
                for j in range {
                    let f = model.bigramFollower(j)
                    biProb[f.idx] = Float(f.count) / total
                }
            }
        }
        if biProb.isEmpty {
            // Missing bigram context
            baseW.unigram += baseW.bigram
            baseW.bigram   = 0
        }

        // User bigram context (last word). Keyed by vocab index so the scoring
        // loop never decodes a word; only the final top `limit` are decoded.
        let userFollowers: [String: Int] = context.last.flatMap { userBigramChain[$0] } ?? [:]
        let userTotal = Float(max(1, userFollowers.values.reduce(0, +)))
        var userCounts = [Int: Int]()
        for (word, count) in userFollowers {
            if let idx = model.index(of: word) { userCounts[idx, default: 0] += count }
        }

        var results = [(idx: Int, score: Float)]()
        results.reserveCapacity(candidates.count)

        for idx in candidates {
            var w = baseW

            let triScore = triProb[idx] ?? 0
            let biScore  = biProb[idx] ?? 0

            // Unigram score (convert log-prob back to linear for blending)
            let uniScore: Float = exp(model.unigramLogProb(idx))

            // User bigram score
            var userScore: Float = 0
            let userCount = Float(userCounts[idx] ?? 0)
            if userCount > 0 {
                userScore = userCount / userTotal
                // Boost user weight if well-trained
                if userCount >= 5 {
                    let boost: Float = 0.25
                    w.userBigram = boost
                    // Renormalize others proportionally
                    let otherSum = w.trigram + w.bigram + w.unigram
                    if otherSum > 0 {
                        let scale = (1.0 - boost) / otherSum
                        w.trigram  *= scale
                        w.bigram   *= scale
                        w.unigram  *= scale
                    }
                }
            }

            let score = w.trigram * triScore
                      + w.bigram  * biScore
                      + w.unigram * uniScore
                      + w.userBigram * userScore

            results.append((idx: idx, score: score))
        }

        results.sort { $0.score > $1.score }
        return results.prefix(limit).map { (word: model.word($0.idx), score: $0.score) }
    }

    // MARK: - Helpers

    /// Returns a compact set of candidate indices based on bigram/trigram top followers.
    private func topCandidateIndices(ctx1: Int?, ctx2: Int?, model: MappedNGramModel) -> [Int] {
        var idxSet = Set<Int>()

        if let c2 = ctx2 {
            for j in model.bigramRange(context: c2) { idxSet.insert(model.bigramFollower(j).idx) }

            if let c1 = ctx1 {
                for j in model.trigramRange(c1, c2) { idxSet.insert(model.trigramFollower(j).idx) }
            }
        }

        // Pad with top-frequency unigrams if candidate set is thin
        if idxSet.count < 20 {
            for i in 0..<min(50, model.vocabSize) { idxSet.insert(i) }
        }

        return Array(idxSet)
    }
}
