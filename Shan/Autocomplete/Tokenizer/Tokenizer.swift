//
//  Tokenizer.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 24/9/2567 BE.
//

import Foundation

public class Tokenizer {

    // The tokenizer shares DictionaryService's memory-mapped lexicon, so it
    // adds no copy of the word list. DictionaryService swaps the lexicon in on
    // the main thread and tokenize() callers run on main.
    private var dictionary: DictionaryService { SharedResources.shared.dictionaryService }
    private var maxWordLength: Int { dictionary.maxWordLength }
    private var isLoaded: Bool { dictionary.isLoaded }

    // LRU cache using NSCache (auto-evicts under memory pressure)
    private var tokenizationCache = NSCache<NSString, TokenizationCacheEntry>()
    private var splitCache = NSCache<NSString, TokenizationCacheEntry>()

    init() {
        let lowRAM = ProcessInfo.processInfo.physicalMemory < 5_368_709_120
        tokenizationCache.countLimit = lowRAM ? 50 : 200
        splitCache.countLimit = lowRAM ? 50 : 200
    }

    // MARK: - Public API

    public func tokenize(_ text: String) -> [String] {
        guard isLoaded && !text.isEmpty else { return [] }

        let key = text as NSString
        if let cached = tokenizationCache.object(forKey: key) {
            return cached.tokens
        }

        let tokens = maximalMatching(text)
        tokenizationCache.setObject(TokenizationCacheEntry(tokens), forKey: key)
        return tokens
    }

    /// Splits a dictionary entry into its known constituent words, e.g.
    /// "ၵတ်းသၼ်ႇၵတ်းၼၢဝ်" -> ["ၵတ်းသၼ်ႇ", "ၵတ်းၼၢဝ်"]. Returns nil unless every
    /// piece is itself a real dictionary word — a split that falls back to a raw
    /// character the dictionary can't explain is rejected rather than shown.
    public func splitCompoundWord(_ word: String) -> [String]? {
        guard isLoaded, word.unicodeScalars.count >= 4 else { return nil }

        let key = word as NSString
        if let cached = splitCache.object(forKey: key) {
            return cached.tokens.isEmpty ? nil : cached.tokens
        }

        let tokens = maximalMatching(word, excludeFullMatch: true)
        let dictionary = self.dictionary
        let isCleanSplit = tokens.count >= 2 && tokens.allSatisfy { dictionary.containsWord($0) }
        let result = isCleanSplit ? tokens : []
        splitCache.setObject(TokenizationCacheEntry(result), forKey: key)
        return isCleanSplit ? tokens : nil
    }

    /// Maximal matching via dynamic programming.
    /// Finds the segmentation that minimizes the total number of tokens
    /// (preferring longer dictionary words over single-character fallbacks).
    private func maximalMatching(_ text: String, excludeFullMatch: Bool = false) -> [String] {
        let dictionary = self.dictionary
        let maxWordLength = self.maxWordLength
        let chars = Array(text)
        let n = chars.count

        // cost[i] = minimum number of tokens to segment chars[0..<i]
        var cost = Array(repeating: Int.max, count: n + 1)
        // parent[i] = the start index of the last token in the optimal segmentation of chars[0..<i]
        var parent = Array(repeating: 0, count: n + 1)
        cost[0] = 0

        for i in 1...n {
            // Option 1: single character fallback (always available)
            if cost[i - 1] != Int.max {
                let newCost = cost[i - 1] + 1
                if newCost < cost[i] {
                    cost[i] = newCost
                    parent[i] = i - 1
                }
            }

            // Option 2: try all dictionary words ending at position i
            let upperBound = (excludeFullMatch && i == n) ? n - 1 : i
            let maxLen = min(maxWordLength, upperBound)
            guard maxLen >= 2 else { continue }
            for len in 2...maxLen {
                let start = i - len
                guard cost[start] != Int.max else { continue }
                let substring = String(chars[start..<i])
                if dictionary.containsWord(substring) {
                    let newCost = cost[start] + 1
                    if newCost < cost[i] || (newCost == cost[i] && len > (i - parent[i])) {
                        cost[i] = newCost
                        parent[i] = start
                    }
                }
            }
        }

        // Backtrack to recover tokens
        var tokens: [String] = []
        var pos = n
        while pos > 0 {
            let start = parent[pos]
            tokens.append(String(chars[start..<pos]))
            pos = start
        }
        tokens.reverse()
        return tokens
    }

    public func tokenizeLastPart(_ text: String, maxLength: Int = 100) -> [String] {
        let processText = text.count > maxLength ? String(text.suffix(maxLength)) : text
        return tokenize(processText)
    }

    public func wordExists(_ word: String) -> Bool {
        return dictionary.containsWord(word)
    }

    /// Check if a string could be the start of a valid dictionary word
    public func isValidPrefix(_ prefix: String) -> Bool {
        return dictionary.isWordPrefix(prefix)
    }

    public func getDictionaryStats() -> (wordCount: Int, maxLength: Int, isLoaded: Bool) {
        return (0, maxWordLength, isLoaded)
    }

    public func clearCache() {
        tokenizationCache.removeAllObjects()
        splitCache.removeAllObjects()
    }
}

// MARK: - Singleton & Convenience

extension Tokenizer {

    static let shared = Tokenizer()

    public func getLastToken(from text: String) -> String? {
        guard !text.isEmpty else { return nil }

        let workingText = text.count > 100 ? String(text.suffix(100)) : text
        let tokens = tokenize(workingText)
        return tokens.last
    }

    public func findWordsStartingWith(_ prefix: String, limit: Int = 10) -> [String] {
        guard !prefix.isEmpty else { return [] }
        return dictionary.searchWords(prefix: prefix, limit: limit).map { $0.word }
    }
}

// Wrapper class for NSCache storage
private class TokenizationCacheEntry: NSObject {
    let tokens: [String]
    init(_ tokens: [String]) {
        self.tokens = tokens
    }
}
