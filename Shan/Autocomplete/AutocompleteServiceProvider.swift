//
//  AutocompleteServiceProvider.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import Foundation
import KeyboardKit

class AutocompleteServiceProvider: AutocompleteService {
    init(context: AutocompleteContext) {
        self.context = context
        loadUserWords()
        loadDictionaryWords()
        loadIgnoredWords()
        loadLearnedWords()
        buildMarkovChain()
    }

    private var context: AutocompleteContext
    private var userWordFrequency: [String: Int] = [:]
    private var dictionaryWords: Set<String> = []
    private var currentInput: String = ""
    private var recentWords: [String] = []
    private var markovChain: [String: [String: Int]] = [:]
    private let chainOrder = 2
    private let maxRecentWords = 10
    private let suggestionCache = NSCache<NSString, NSArray>()
    
    var locale: Locale = .current
    
    var canIgnoreWords: Bool { true }
    var canLearnWords: Bool { true }
    var ignoredWords: [String] = []
    var learnedWords: [String] = []
    
    func hasIgnoredWord(_ word: String) -> Bool { ignoredWords.contains(word) }
    func hasLearnedWord(_ word: String) -> Bool { learnedWords.contains(word) }
    
    func ignoreWord(_ word: String) {
        ignoredWords.append(word)
        saveIgnoredWords()
    }
    
    func learnWord(_ word: String) {
        learnedWords.append(word)
        incrementWordFrequency(word)
        saveLearnedWords()
    }
    
    func removeIgnoredWord(_ word: String) {
        ignoredWords.removeAll { $0 == word }
        saveIgnoredWords()
    }
    
    func unlearnWord(_ word: String) {
        learnedWords.removeAll { $0 == word }
        userWordFrequency[word] = nil
        saveLearnedWords()
        saveUserWords()
    }
    
    func autocompleteSuggestions(
        for text: String
    ) async throws -> [Autocomplete.Suggestion] {
        guard text.count > 0 else { return [] }
        updateCurrentInput(with: text)
        
        // Check cache first
        if let cachedSuggestions = suggestionCache.object(forKey: text as NSString) as? [Autocomplete.Suggestion] {
            return cachedSuggestions
        }
        
        let suggestions = getSuggestions(for: currentInput)
        suggestionCache.setObject(suggestions as NSArray, forKey: text as NSString)
        return suggestions
    }

    func nextCharacterPredictions(
        forText text: String,
        suggestions: [Autocomplete.Suggestion]
    ) async throws -> [Character : Double] {
        var predictions: [Character: Double] = [:]
        let allWords = Set(userWordFrequency.keys).union(dictionaryWords)
        
        for word in allWords where word.hasPrefix(text) {
            if let nextChar = word.dropFirst(text.count).first {
                predictions[nextChar, default: 0] += Double(userWordFrequency[word, default: 1])
            }
        }
        
        let total = predictions.values.reduce(0, +)
        return predictions.mapValues { $0 / total }
    }
    
    private func getSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        var suggestions: [Autocomplete.Suggestion] = []
        
        // Context-aware suggestions using Markov chain
        if let contextSuggestions = getContextBasedSuggestions(for: text) {
            suggestions.append(contentsOf: contextSuggestions)
        }
        
        // User's most used words with frequency boost
        let userSuggestions = userWordFrequency.keys
            .filter { $0.hasPrefix(text) && !ignoredWords.contains($0) }
            .sorted { 
                let freq1 = userWordFrequency[$0] ?? 0
                let freq2 = userWordFrequency[$1] ?? 0
                return freq1 > freq2
            }
            .prefix(context.suggestionsDisplayCount - suggestions.count)
            .map { Autocomplete.Suggestion(text: $0, type: .unknown) }
        
        suggestions.append(contentsOf: userSuggestions)
        
        // Dictionary suggestions with smart filtering
        let dictionarySuggestions = dictionaryWords
            .filter { word in
                word.hasPrefix(text) && 
                !ignoredWords.contains(word) &&
                !suggestions.contains { $0.text == word }
            }
            .prefix(context.suggestionsDisplayCount - suggestions.count)
            .map { Autocomplete.Suggestion(text: $0, type: .regular) }
        
        suggestions.append(contentsOf: dictionarySuggestions)
        
        // Smart fallback suggestions
        if suggestions.count < 3 {
            let fallbackSuggestions = getSmartFallbackSuggestions(for: text)
            suggestions.append(contentsOf: fallbackSuggestions)
        }
        
        // Enhanced autocorrect
        if let autocorrect = findClosestMatch(for: text), autocorrect != text {
            let autocorrectSuggestion = Autocomplete.Suggestion(text: autocorrect, type: .autocorrect)
            if !suggestions.contains(where: { $0.text == autocorrect }) {
                suggestions.insert(autocorrectSuggestion, at: 0)
            }
        }
        
        return Array(suggestions.prefix(context.suggestionsDisplayCount))
    }
    
    private func getContextBasedSuggestions(for text: String) -> [Autocomplete.Suggestion]? {
        guard !recentWords.isEmpty else { return nil }
        
        let context = recentWords.suffix(chainOrder).joined(separator: " ")
        return markovChain[context]?
            .filter { $0.key.hasPrefix(text) }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { Autocomplete.Suggestion(text: $0.key, type: .regular) }
    }
    
    private func getSmartFallbackSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        let minPrefixLength = 2
        let prefix = String(text.prefix(minPrefixLength))
        
        return dictionaryWords
            .filter { word in
                (word.contains(text) || word.commonPrefix(with: text).count >= minPrefixLength) &&
                !ignoredWords.contains(word)
            }
            .sorted { word1, word2 in
                let score1 = calculateWordScore(word1, prefix: prefix)
                let score2 = calculateWordScore(word2, prefix: prefix)
                return score1 > score2
            }
            .prefix(3)
            .map { Autocomplete.Suggestion(text: $0, type: .regular) }
    }
    
    private func calculateWordScore(_ word: String, prefix: String) -> Double {
        var score = 0.0
        
        // Length similarity
        score += 1.0 - Double(abs(word.count - prefix.count)) / Double(max(word.count, prefix.count))
        
        // Prefix match bonus
        if word.hasPrefix(prefix) {
            score += 0.5
        }
        
        // User frequency bonus
        if let frequency = userWordFrequency[word] {
            score += Double(frequency) * 0.1
        }
        
        return score
    }
    
    private func buildMarkovChain() {
        let allWords = Set(userWordFrequency.keys).union(dictionaryWords)
        for word in allWords {
            let words = word.components(separatedBy: .whitespaces)
            
            // Skip words that are too short to form a context
            if words.count <= chainOrder {
                continue
            }
            
            for i in 0...(words.count - chainOrder - 1) {
                let context = words[i..<(i + chainOrder)].joined(separator: " ")
                let nextWord = words[i + chainOrder]
                markovChain[context, default: [:]][nextWord, default: 0] += 1
            }
        }
    }
    
    private func updateCurrentInput(with text: String) {
        currentInput = text
        if !text.isEmpty {
            recentWords.append(text)
            if recentWords.count > maxRecentWords {
                recentWords.removeFirst()
            }
        }
    }
    
    private func findClosestMatch(for word: String) -> String? {
        let allWords = Set(userWordFrequency.keys).union(dictionaryWords).subtracting(ignoredWords)
        return allWords
            .filter { abs($0.count - word.count) <= 2 }
            .min(by: { levenshteinDistance(word, $0) < levenshteinDistance(word, $1) })
    }
        
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        for (i, c1) in s1.enumerated() {
            for (j, c2) in s2.enumerated() {
                if c1 == c2 {
                    matrix[i+1][j+1] = matrix[i][j]
                } else {
                    matrix[i+1][j+1] = min(matrix[i][j+1], matrix[i+1][j], matrix[i][j]) + 1
                }
            }
        }
        
        return matrix[m][n]
    }
    
    private func incrementWordFrequency(_ word: String) {
        userWordFrequency[word, default: 0] += 1
        saveUserWords()
    }
    
    private func loadUserWords() {
        userWordFrequency = UserDefaults.standard.object(forKey: "UserWordFrequency") as? [String: Int] ?? [:]
    }
    
    private func saveUserWords() {
        UserDefaults.standard.set(userWordFrequency, forKey: "UserWordFrequency")
    }
    
    private func loadDictionaryWords() {
        if let path = Bundle.main.path(forResource: "dictionary", ofType: "txt"),
           let content = try? String(contentsOfFile: path) {
            dictionaryWords = Set(content.components(separatedBy: .newlines))
        }
    }
    
    private func loadIgnoredWords() {
        ignoredWords = UserDefaults.standard.object(forKey: "IgnoredWords") as? [String] ?? []
    }
    
    private func saveIgnoredWords() {
        UserDefaults.standard.set(ignoredWords, forKey: "IgnoredWords")
    }
    
    private func loadLearnedWords() {
        learnedWords = UserDefaults.standard.object(forKey: "LearnedWords") as? [String] ?? []
    }
    
    private func saveLearnedWords() {
        UserDefaults.standard.set(learnedWords, forKey: "LearnedWords")
    }
}

