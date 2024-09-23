//
//  FakeAutocompleteService.swift
//  Panglong_iKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import Foundation
import KeyboardKit
import UIKit

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
    private var markovChain: [String: [String: Int]] = [:]
    private let chainOrder = 2 // Order of the Markov chain
    
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
        addToMarkovChain(word)
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
        return getSuggestions(for: text)
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
        
        // Use Markov chain for additional predictions
        let markovPredictions = predictNextCharacters(for: text)
        for (char, prob) in markovPredictions {
            predictions[char, default: 0] += prob * 10 // Adjust weight as needed
        }
        
        let total = predictions.values.reduce(0, +)
        return predictions.mapValues { $0 / total }
    }
    
    func selectSuggestion(_ suggestion: Autocomplete.Suggestion) {
        // Learn only the suggested word, not the full input
        learnWord(suggestion.text)
        
        // Update the current input only with the last word (if relevant)
        let tokenizedWords = Tokenizer.tokenize(currentInput)
        if let lastWord = tokenizedWords.last, suggestion.text.hasPrefix(lastWord) {
            updateCurrentInput(with: suggestion.text)
        }
    }

    
    private func updateCurrentInput(with text: String) {
        let tokenizedWords = Tokenizer.tokenize(text)
        currentInput = tokenizedWords.joined()
    }
    
    private func getSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        let tokenizedWords = Tokenizer.tokenize(text)
        let lastWord = tokenizedWords.last ?? ""
        var suggestions: [Autocomplete.Suggestion] = []
        
        // Get context-aware suggestions from the Markov chain
        let contextWords = Array(tokenizedWords.dropLast(1))
        let markovSuggestions = predictNextWords(after: contextWords, startingWith: lastWord, maxSuggestions: context.suggestionsDisplayCount)
        suggestions.append(contentsOf: markovSuggestions.map { Autocomplete.Suggestion(text: $0, type: .regular) })
        
        // Add user's most used words
        let userSuggestions = userWordFrequency.keys
            .filter { $0.hasPrefix(lastWord) && !ignoredWords.contains($0) }
            .sorted { userWordFrequency[$0]! > userWordFrequency[$1]! }
            .prefix(context.suggestionsDisplayCount - suggestions.count)
            .map { Autocomplete.Suggestion(text: $0, type: .unknown) }
        
        suggestions.append(contentsOf: userSuggestions)
        
        // Add more suggestions from the dictionary if needed
        if suggestions.count < context.suggestionsDisplayCount {
            let dictionarySuggestions = dictionaryWords
                .filter { $0.hasPrefix(lastWord) && !ignoredWords.contains($0) }
                .prefix(context.suggestionsDisplayCount - suggestions.count)
                .map { Autocomplete.Suggestion(text: $0, type: .regular) }
            
            suggestions.append(contentsOf: dictionarySuggestions)
        }
        
        // Don't attach the full prefix in Shan language
        // Just return the last word suggestion
        return Array(suggestions.prefix(context.suggestionsDisplayCount))
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
    
    private func buildMarkovChain() {
        let allWords = Array(dictionaryWords) + learnedWords
        for i in 0..<allWords.count {
            let startIndex = max(0, i - chainOrder)
            let context = allWords[startIndex..<i].joined()
            let word = allWords[i]
            markovChain[context, default: [:]][word, default: 0] += 1
        }
    }
    
    private func addToMarkovChain(_ word: String) {
        let words = Tokenizer.tokenize(currentInput) + [word]
        for i in chainOrder..<words.count {
            let context = words[i-chainOrder..<i].joined()
            markovChain[context, default: [:]][words[i], default: 0] += 1
        }
    }
    
    private func predictNextWords(after context: [String], startingWith prefix: String, maxSuggestions: Int) -> [String] {
        var suggestions: [String] = []
        let contextString = context.suffix(chainOrder - 1).joined()
        
        if let nextWords = markovChain[contextString] {
            let sortedWords = nextWords.sorted { $0.value > $1.value }
            for (word, _) in sortedWords {
                if word.hasPrefix(prefix) && !suggestions.contains(word) {
                    suggestions.append(word)
                    if suggestions.count >= maxSuggestions {
                        break
                    }
                }
            }
        }
        
        return suggestions
    }
    
    private func predictNextCharacters(for text: String) -> [Character: Double] {
        var predictions: [Character: Double] = [:]
        let words = Tokenizer.tokenize(text)
        let context = words.suffix(chainOrder - 1).joined()
        
        if let nextWords = markovChain[context] {
            let total = Double(nextWords.values.reduce(0, +))
            for (word, count) in nextWords {
                if let firstChar = word.first {
                    predictions[firstChar, default: 0] += Double(count) / total
                }
            }
        }
        
        return predictions
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
