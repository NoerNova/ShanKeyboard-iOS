//
//  NGramService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 16/3/2569 BE.
//

import Foundation

// MARK: - Model

private struct NGramModel {
    let vocab: [String]
    let vocabIndex: [String: Int]
    let unigramLogProbs: [Float]

    // Bigram stored as CSR (Compressed Sparse Row)
    // bigramOffsets[i] ..< bigramOffsets[i+1] → indices into bigramFollowers for context word i
    // Int32 (not Int) halves the resident size of these large arrays.
    let bigramOffsets: [Int32]
    let bigramFollowers: [(idx: Int32, count: UInt16)]

    // Trigram: sparse dict key = Int64(ctx1) << 32 | Int64(ctx2)
    let trigramTable: [Int64: [(idx: Int32, count: UInt16)]]

    var vocabSize: Int { vocab.count }
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
    private var model: NGramModel?

    /// Devices with < 5 GB RAM (iPhone 13/14 class) crash under the NGram model's
    /// load peak + resident footprint. On those devices we skip it entirely and let
    /// suggestions fall back to the dictionary + personal bigram chain.
    private let lowRAM = ProcessInfo.processInfo.physicalMemory < 5_368_709_120

    // MARK: - Async Loading

    /// Loads the model from bundle on a background queue.
    func loadAsync(completion: (() -> Void)? = nil) {
        guard !lowRAM else {
            // Skip loading: `model` stays nil (scoredCandidates returns []), but report
            // loaded so the caller's chain doesn't wait on a model that never arrives.
            isLoaded = true
            completion?()
            return
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.loadModel()
            DispatchQueue.main.async {
                self?.isLoaded = true
                completion?()
            }
        }
    }

    /// Releases the in-memory model (~15–25 MB) under severe memory pressure.
    /// Suggestions will fall back to DictionaryService until reloaded.
    func purge() {
        model = nil
        isLoaded = false
    }

    private func loadModel() {
        guard
            let url = Bundle.main.url(forResource: "bigram_data", withExtension: "plist")
                   ?? extensionBundle().url(forResource: "bigram_data", withExtension: "plist")
                   ?? Bundle.main.url(forResource: "bigram_data", withExtension: "json")
                   ?? extensionBundle().url(forResource: "bigram_data", withExtension: "json")
        else {
            return
        }

        do {
            // autoreleasepool releases the boxed Foundation object graph from
            // PropertyListSerialization/JSONSerialization as soon as the compact CSR
            // model is built, instead of letting it linger to the next main-loop drain.
            // This is the largest transient peak during extension startup.
            model = try autoreleasepool { () -> NGramModel? in
                // .alwaysMapped lets iOS evict the raw file pages under memory pressure
                // without terminating the extension process.
                let data = try Data(contentsOf: url, options: .alwaysMapped)
                let raw: [String: Any]?
                if url.pathExtension == "plist" {
                    raw = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
                } else {
                    raw = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                }
                guard let raw else { return nil }
                return try parseModel(raw)
            }
        } catch {
            // Model unavailable — fallback to legacy path remains active
        }
    }

    /// Keyboard extensions load resources from their own bundle, not the host app.
    private func extensionBundle() -> Bundle {
        // Walk up from the current class to find the correct bundle
        return Bundle(for: NGramService.self)
    }

    private func parseModel(_ raw: [String: Any]) throws -> NGramModel {
        guard
            let vocabArray = raw["vocab"] as? [String],
            let unigramRaw = raw["unigram_log_probs"] as? [NSNumber],
            let bigramsRaw = raw["bigrams"] as? [[NSNumber]],
            let trigramsRaw = raw["trigrams"] as? [[NSNumber]]
        else {
            throw NSError(domain: "NGramService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"])
        }

        // Keep first occurrence of any duplicate word (safe merge instead of trapping init)
        var vocabIndex = [String: Int](minimumCapacity: vocabArray.count)
        for (i, word) in vocabArray.enumerated() {
            if vocabIndex[word] == nil { vocabIndex[word] = i }
        }
        let unigramLogProbs = unigramRaw.map { $0.floatValue }
        let n = vocabArray.count

        // Build CSR bigram table
        var bigramOffsets = [Int32](repeating: 0, count: n + 1)
        // First pass: count followers per context
        for entry in bigramsRaw {
            guard entry.count >= 3 else { continue }
            let ctx = entry[0].intValue
            if ctx < n { bigramOffsets[ctx + 1] += 1 }
        }
        // Prefix sum
        for i in 1...n { bigramOffsets[i] += bigramOffsets[i - 1] }

        var bigramFollowers = [(idx: Int32, count: UInt16)](
            repeating: (idx: 0, count: 0),
            count: bigramsRaw.count
        )
        var insertPos = bigramOffsets // copy for tracking write positions
        for entry in bigramsRaw {
            guard entry.count >= 3 else { continue }
            let ctx = entry[0].intValue
            let fol = entry[1].intValue
            let cnt = min(entry[2].intValue, Int(UInt16.max))
            if ctx < n {
                bigramFollowers[Int(insertPos[ctx])] = (idx: Int32(fol), count: UInt16(cnt))
                insertPos[ctx] += 1
            }
        }

        // Build sparse trigram dict
        var trigramTable = [Int64: [(idx: Int32, count: UInt16)]]()
        trigramTable.reserveCapacity(trigramsRaw.count / 5)
        for entry in trigramsRaw {
            guard entry.count >= 4 else { continue }
            let ctx1 = Int64(entry[0].intValue)
            let ctx2 = Int64(entry[1].intValue)
            let fol  = entry[2].intValue
            let cnt  = min(entry[3].intValue, Int(UInt16.max))
            let key  = (ctx1 << 32) | ctx2
            trigramTable[key, default: []].append((idx: Int32(fol), count: UInt16(cnt)))
        }

        return NGramModel(
            vocab: vocabArray,
            vocabIndex: vocabIndex,
            unigramLogProbs: unigramLogProbs,
            bigramOffsets: bigramOffsets,
            bigramFollowers: bigramFollowers,
            trigramTable: trigramTable
        )
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
        let ctx1Idx: Int? = context.count >= 2 ? model.vocabIndex[context[context.count - 2]] : nil
        let ctx2Idx: Int? = context.isEmpty    ? nil : model.vocabIndex[context.last!]

        // Decide which candidates to score: vocab filtered by partialNext
        let candidates: [Int]
        if partialNext.isEmpty {
            // Score all vocab — use trigram/bigram followers as candidate set for speed
            candidates = topCandidateIndices(ctx1: ctx1Idx, ctx2: ctx2Idx, model: model)
        } else {
            // Filter vocab by prefix using unicode scalars —
            // grapheme-level hasPrefix fails for Shan combining characters
            // e.g. "မႂ်ႇမႂ်ႇ".hasPrefix("မႂ်ႇ") is false at grapheme level.
            let partialScalars = Array(partialNext.unicodeScalars)
            candidates = model.vocab.indices.filter { i in
                model.vocab[i].unicodeScalars.starts(with: partialScalars)
            }
        }

        // User bigram context (last word)
        let userCtxWord = context.last
        let userFollowers: [String: Int] = userCtxWord.flatMap { userBigramChain[$0] } ?? [:]
        let userTotal = Float(max(1, userFollowers.values.reduce(0, +)))

        var results = [(word: String, score: Float)]()
        results.reserveCapacity(candidates.count)

        for idx in candidates {
            let word = model.vocab[idx]
            var w = defaultWeights()

            // Trigram score
            var triScore: Float = 0
            if let c1 = ctx1Idx, let c2 = ctx2Idx {
                let key = Int64(c1) << 32 | Int64(c2)
                if let followers = model.trigramTable[key] {
                    let total = Float(followers.reduce(0) { $0 + Int($1.count) })
                    if let entry = followers.first(where: { Int($0.idx) == idx }) {
                        triScore = Float(entry.count) / total
                    }
                } else {
                    // Missing trigram context — redistribute λ₃
                    w.bigram  += w.trigram * 0.70
                    w.unigram += w.trigram * 0.30
                    w.trigram  = 0
                }
            } else {
                w.bigram  += w.trigram * 0.70
                w.unigram += w.trigram * 0.30
                w.trigram  = 0
            }

            // Bigram score
            var biScore: Float = 0
            if let c2 = ctx2Idx {
                let start = Int(model.bigramOffsets[c2])
                let end   = Int(model.bigramOffsets[c2 + 1])
                if start < end {
                    let slice = model.bigramFollowers[start..<end]
                    let total = Float(slice.reduce(0) { $0 + Int($1.count) })
                    if let entry = slice.first(where: { Int($0.idx) == idx }) {
                        biScore = Float(entry.count) / total
                    }
                } else {
                    // Missing bigram context
                    w.unigram += w.bigram
                    w.bigram   = 0
                }
            } else {
                w.unigram += w.bigram
                w.bigram   = 0
            }

            // Unigram score (convert log-prob back to linear for blending)
            let uniScore: Float = exp(model.unigramLogProbs[idx])

            // User bigram score
            var userScore: Float = 0
            let userCount = Float(userFollowers[word] ?? 0)
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

            results.append((word: word, score: score))
        }

        results.sort { $0.score > $1.score }
        return Array(results.prefix(limit))
    }

    // MARK: - Helpers

    private func defaultWeights() -> Weights { Weights() }

    /// Returns a compact set of candidate indices based on bigram/trigram top followers.
    private func topCandidateIndices(ctx1: Int?, ctx2: Int?, model: NGramModel) -> [Int] {
        var idxSet = Set<Int>()

        if let c2 = ctx2 {
            let start = Int(model.bigramOffsets[c2])
            let end   = Int(model.bigramOffsets[c2 + 1])
            for entry in model.bigramFollowers[start..<end] { idxSet.insert(Int(entry.idx)) }

            if let c1 = ctx1 {
                let key = Int64(c1) << 32 | Int64(c2)
                if let followers = model.trigramTable[key] {
                    for entry in followers { idxSet.insert(Int(entry.idx)) }
                }
            }
        }

        // Pad with top-frequency unigrams if candidate set is thin
        if idxSet.count < 20 {
            for i in 0..<min(50, model.vocabSize) { idxSet.insert(i) }
        }

        return Array(idxSet)
    }
}
