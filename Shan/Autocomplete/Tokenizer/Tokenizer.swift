//
//  Tokenizer.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 24/9/2567 BE.
//

import Foundation

public class Tokenizer {

    private var dictionaryTrie = TrieNode()
    private var maxWordLength: Int = 0
    private var isLoaded = false

    // LRU cache using NSCache (auto-evicts under memory pressure)
    private var tokenizationCache = NSCache<NSString, TokenizationCacheEntry>()

    init() {
        tokenizationCache.countLimit = 200
        loadDictionary()
    }

    private func loadDictionary() {
        guard let path = Bundle.main.path(forResource: "dictionary", ofType: "txt") else {
            return
        }

        do {
            let content = try String(contentsOfFile: path)
            let words = content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            for word in words {
                dictionaryTrie.insert(word, frequency: 1)
                maxWordLength = max(maxWordLength, word.count)
            }
            isLoaded = true
        } catch {
            print("Error loading dictionary: \(error)")
        }
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

    /// Maximal matching via dynamic programming.
    /// Finds the segmentation that minimizes the total number of tokens
    /// (preferring longer dictionary words over single-character fallbacks).
    private func maximalMatching(_ text: String) -> [String] {
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
            let maxLen = min(maxWordLength, i)
            guard maxLen >= 2 else { continue }
            for len in 2...maxLen {
                let start = i - len
                guard cost[start] != Int.max else { continue }
                let substring = String(chars[start..<i])
                if dictionaryTrie.contains(substring) {
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
        return dictionaryTrie.contains(word)
    }

    /// Check if a string could be the start of a valid dictionary word
    public func isValidPrefix(_ prefix: String) -> Bool {
        return dictionaryTrie.hasPrefix(prefix)
    }

    public func getDictionaryStats() -> (wordCount: Int, maxLength: Int, isLoaded: Bool) {
        return (0, maxWordLength, isLoaded)
    }

    public func clearCache() {
        tokenizationCache.removeAllObjects()
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
        guard !prefix.isEmpty, let node = dictionaryTrie.searchPrefix(prefix) else { return [] }
        return node.getAllWords(limit: limit).map { $0.word }
    }
}

// Wrapper class for NSCache storage
private class TokenizationCacheEntry: NSObject {
    let tokens: [String]
    init(_ tokens: [String]) {
        self.tokens = tokens
    }
}
