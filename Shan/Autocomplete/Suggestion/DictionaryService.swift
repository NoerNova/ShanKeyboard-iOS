//
//  DictionaryService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 17/7/2568 BE.
//

import Foundation
import KeyboardKit

class DictionaryService {
    private(set) var trie = TrieNode()
    private(set) var syllableTrie = TrieNode()
    private(set) var isLoaded = false
    private var searchCache = NSCache<NSString, NSArray>()
    private var validWordCache = NSCache<NSString, NSNumber>()

    // Bigram data: word -> [(nextWord, frequency)]
    private var bigramData: [String: [(word: String, frequency: Int)]] = [:]

    // Top frequency words for fallback suggestions
    private(set) var topWords: [String] = []

    init() {
        // Smaller caches on low-RAM devices (< 5 GB physical memory)
        let lowRAM = ProcessInfo.processInfo.physicalMemory < 5_368_709_120
        searchCache.countLimit = lowRAM ? 100 : 500
        validWordCache.countLimit = lowRAM ? 500 : 2000
    }

    // MARK: - Async Loading

    func loadAsync(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let (newTrie, newSyllableTrie, newTopWords) = self.buildDictionaryData()
            DispatchQueue.main.async {
                self.trie = newTrie
                self.syllableTrie = newSyllableTrie
                self.topWords = newTopWords
                self.isLoaded = true
                completion?()
            }
        }
    }

    // MARK: - Dictionary Loading

    private func buildDictionaryData() -> (TrieNode, TrieNode, [String]) {
        guard let url = Bundle.main.url(forResource: "filtered_frequency_data", withExtension: "plist")
                     ?? Bundle(for: DictionaryService.self).url(forResource: "filtered_frequency_data", withExtension: "plist")
                     ?? Bundle.main.url(forResource: "filtered_frequency_data", withExtension: "json")
                     ?? Bundle(for: DictionaryService.self).url(forResource: "filtered_frequency_data", withExtension: "json"),
              // .alwaysMapped lets iOS page out the raw bytes under memory pressure
              // instead of keeping the full file resident in the extension's dirty memory.
              let data = try? Data(contentsOf: url, options: .alwaysMapped) else {
            return (TrieNode(), TrieNode(), [])
        }

        let dictionaryData: DictionaryData?
        if url.pathExtension == "plist" {
            dictionaryData = try? PropertyListDecoder().decode(DictionaryData.self, from: data)
        } else {
            dictionaryData = try? JSONDecoder().decode(DictionaryData.self, from: data)
        }

        guard let dictionaryData else {
            return (TrieNode(), TrieNode(), [])
        }

        let newTrie = TrieNode()
        var wordsByFreq: [(String, Int)] = []
        for entry in dictionaryData.words {
            newTrie.insert(entry.word, frequency: entry.frequency)
            wordsByFreq.append((entry.word, entry.frequency))
        }

        let newSyllableTrie = TrieNode()
        for entry in dictionaryData.syllables {
            newSyllableTrie.insert(entry.syllable, frequency: entry.frequency)
        }

        wordsByFreq.sort { $0.1 > $1.1 }
        let newTopWords = wordsByFreq.prefix(100).map { $0.0 }

        return (newTrie, newSyllableTrie, newTopWords)
    }

    // MARK: - Prefix Validation

    /// Fast trie-based prefix check - replaces scanning common words
    func couldBeValidWordPrefix(_ prefix: String) -> Bool {
        return trie.hasPrefix(prefix)
    }

    // MARK: - Suggestions

    func getDictionarySuggestions(for prefix: String, limit: Int = 5) -> [Autocomplete.Suggestion] {
        let currentWord = SharedResources.shared.shanLanguageService.getCurrentWord(from: prefix)
        // Always use the raw word from word boundaries when available.
        // Never fall back to Tokenizer — it splits incomplete words incorrectly.
        let activePrefix = !currentWord.isEmpty ? currentWord : (Tokenizer.shared.getLastToken(from: prefix) ?? prefix)
        let matches = searchWords(prefix: activePrefix, limit: limit)
        return matches.map { match in
            Autocomplete.Suggestion(text: match.word, type: .regular)
        }
    }

    func getSyllableSuggestions(for prefix: String, limit: Int = 5) -> [Autocomplete.Suggestion] {
        let currentWord = SharedResources.shared.shanLanguageService.getCurrentWord(from: prefix)
        let activePrefix = !currentWord.isEmpty ? currentWord : (Tokenizer.shared.getLastToken(from: prefix) ?? prefix)
        let matches = searchSyllables(prefix: activePrefix, limit: limit)
        return matches.map { match in
            Autocomplete.Suggestion(text: match.word, type: .regular)
        }
    }

    /// Get next-word suggestions based on frequency, filtered by optional prefix
    func getNextWordSuggestions(after word: String, prefix: String = "", limit: Int = 5) -> [DictionaryMatch] {
        // If we have bigram data for this word, use it
        if let candidates = bigramData[word] {
            let filtered = prefix.isEmpty
                ? candidates
                : candidates.filter { $0.word.hasPrefix(prefix) }
            return filtered.prefix(limit).map {
                DictionaryMatch(word: $0.word, frequency: $0.frequency, type: .dictionary)
            }
        }

        // Fallback: top words filtered by prefix
        if !prefix.isEmpty {
            return searchWords(prefix: prefix, limit: limit)
        }

        return topWords.prefix(limit).map {
            DictionaryMatch(word: $0, frequency: 0, type: .dictionary)
        }
    }

    // MARK: - Search

    func searchWords(prefix: String, limit: Int = 10) -> [DictionaryMatch] {
        let cacheKey = "\(prefix)_\(limit)" as NSString

        if let cached = searchCache.object(forKey: cacheKey) as? [DictionaryMatch] {
            return cached
        }

        guard let prefixNode = trie.searchPrefix(prefix) else {
            return []
        }

        let results = prefixNode.getAllWords(limit: limit).map {
            DictionaryMatch(word: $0.word, frequency: $0.frequency, type: .dictionary)
        }

        searchCache.setObject(results as NSArray, forKey: cacheKey)
        return results
    }

    func searchSyllables(prefix: String, limit: Int = 5) -> [DictionaryMatch] {
        guard let prefixNode = syllableTrie.searchPrefix(prefix) else {
            return []
        }

        return prefixNode.getAllWords(limit: limit).map {
            DictionaryMatch(word: $0.word, frequency: $0.frequency, type: .syllable)
        }
    }

    // MARK: - Validation

    func isValidWord(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }

        let key = text as NSString
        if let cached = validWordCache.object(forKey: key) {
            return cached.boolValue
        }

        let result = trie.contains(text) || syllableTrie.contains(text)
        validWordCache.setObject(NSNumber(value: result), forKey: key)
        return result
    }

    /// Store bigram from user data for next-word prediction
    func addBigram(word: String, nextWord: String, frequency: Int) {
        if bigramData[word] == nil {
            bigramData[word] = []
        }
        if let idx = bigramData[word]?.firstIndex(where: { $0.word == nextWord }) {
            bigramData[word]?[idx] = (nextWord, bigramData[word]![idx].frequency + frequency)
        } else {
            bigramData[word]?.append((word: nextWord, frequency: frequency))
        }
    }
}

// MARK: - Data Structures

struct DictionaryData: Codable {
    let words: [WordEntry]
    let syllables: [SyllableEntry]
}

struct WordEntry: Codable {
    let word: String
    let frequency: Int
    let category: String?
    let meaning: String?
}

struct SyllableEntry: Codable {
    let syllable: String
    let frequency: Int
}

class DictionaryMatch: NSObject {
    let word: String
    let frequency: Int
    let type: MatchType

    enum MatchType {
        case dictionary
        case syllable
        case learned
    }

    init(word: String, frequency: Int, type: MatchType) {
        self.word = word
        self.frequency = frequency
        self.type = type
    }
}
