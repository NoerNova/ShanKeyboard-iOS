//
//  DictionaryService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 17/7/2568 BE.
//

import Foundation
import KeyboardKit

class DictionaryService {
    /// Memory-mapped dictionary (see MappedLexicon.swift). nil until loaded.
    private var lexicon: MappedLexicon?
    /// Longest word length in graphemes — used by Tokenizer's maximal matching.
    private(set) var maxWordLength = 0
    private(set) var isLoaded = false
    private var searchCache = NSCache<NSString, NSArray>()

    // Bigram data: word -> [(nextWord, frequency)]
    private var bigramData: [String: [(word: String, frequency: Int)]] = [:]

    // Top frequency words for fallback suggestions
    private(set) var topWords: [String] = []

    init() {
        // Smaller cache on low-RAM devices (< 5 GB physical memory)
        let lowRAM = ProcessInfo.processInfo.physicalMemory < 5_368_709_120
        searchCache.countLimit = lowRAM ? 100 : 500
    }

    func clearCaches() {
        searchCache.removeAllObjects()
    }

    // MARK: - Async Loading

    /// Maps lexicon.bin. Mapping is near-free; the background hop only covers
    /// the one-time grapheme count for maxWordLength.
    func loadAsync(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let lexicon = MappedFile.resource("lexicon", "bin", for: DictionaryService.self)
                .flatMap(MappedLexicon.init(file:))
            DispatchQueue.main.async {
                guard let self else { return }
                if let lexicon {
                    self.lexicon = lexicon
                    self.topWords = lexicon.topWords
                    self.maxWordLength = lexicon.maxWordLength
                    self.searchCache.removeAllObjects()
                }
                // Stays false if lexicon.bin is missing or corrupt, so the
                // Tokenizer and suggestion paths skip dictionary work.
                self.isLoaded = lexicon != nil
                MemoryProbe.log("dictionary loaded=\(lexicon != nil)")
                completion?()
            }
        }
    }

    // MARK: - Word lookups (allocation-free binary search on mapped bytes)

    func containsWord(_ text: String) -> Bool {
        lexicon?.containsWord(text) ?? false
    }

    func isWordPrefix(_ prefix: String) -> Bool {
        lexicon?.isWordPrefix(prefix) ?? false
    }

    // MARK: - Prefix Validation

    /// Scalar-level prefix check against the dictionary - O(log n)
    func couldBeValidWordPrefix(_ prefix: String) -> Bool {
        return isWordPrefix(prefix)
    }

    // MARK: - Suggestions

    func getDictionarySuggestions(for prefix: String, limit: Int = 5) -> [Autocomplete.Suggestion] {
        let currentWord = SharedResources.shared.shanLanguageService.getCurrentWord(from: prefix)
        // Always use the raw word from word boundaries when available.
        // Never fall back to Tokenizer — it splits incomplete words incorrectly.
        let activePrefix = !currentWord.isEmpty ? currentWord : (Tokenizer.shared.getLastToken(from: prefix) ?? prefix)
        let matches = searchWords(prefix: activePrefix, limit: limit)
        return matches.map { match in
            Autocomplete.Suggestion(text: preferredCompletion(for: match.word, prefix: activePrefix), type: .regular)
        }
    }

    /// Shorter matched word.
    private func preferredCompletion(for word: String, prefix: String) -> String {
        guard let pieces = Tokenizer.shared.splitCompoundWord(word),
              let first = pieces.first,
              first.count > prefix.count,
              first.hasPrefix(prefix) else {
            return word
        }
        return first
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

        guard let lexicon else { return [] }
        let results = lexicon.words.topMatches(prefix: prefix, limit: limit).map {
            DictionaryMatch(word: $0.word, frequency: $0.frequency, type: .dictionary)
        }

        searchCache.setObject(results as NSArray, forKey: cacheKey)
        return results
    }

    func searchSyllables(prefix: String, limit: Int = 5) -> [DictionaryMatch] {
        guard let lexicon else { return [] }
        return lexicon.syllables.topMatches(prefix: prefix, limit: limit).map {
            DictionaryMatch(word: $0.word, frequency: $0.frequency, type: .syllable)
        }
    }

    // MARK: - Validation

    /// A word or syllable in the dictionary. Two binary searches over mapped
    /// bytes, cheaper than the NSCache lookup it replaced, so it is uncached.
    func isValidWord(_ text: String) -> Bool {
        guard !text.isEmpty, let lexicon else { return false }
        return lexicon.containsWord(text) || lexicon.containsSyllable(text)
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
