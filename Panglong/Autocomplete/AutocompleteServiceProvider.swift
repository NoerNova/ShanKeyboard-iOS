//
//  FakeAutocompleteService.swift
//  Panglong_iKeyboard
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
        return getSuggestions(for: currentInput)
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
    
    private func updateCurrentInput(with text: String) {
        currentInput = text
    }
    
    private func getSuggestions(for text: String) -> [Autocomplete.Suggestion] {
         var suggestions: [Autocomplete.Suggestion] = []
         
         // Add user's most used words
         let userSuggestions = userWordFrequency.keys
             .filter { $0.hasPrefix(text) && !ignoredWords.contains($0) }
             .sorted { userWordFrequency[$0]! > userWordFrequency[$1]! }
             .prefix(context.suggestionsDisplayCount - suggestions.count)
             .map { Autocomplete.Suggestion(text: $0, type: .unknown) }
         
         suggestions.append(contentsOf: userSuggestions)
         
         // Add dictionary suggestions
         let dictionarySuggestions = dictionaryWords
             .filter { $0.hasPrefix(text) && !ignoredWords.contains($0) }
             .prefix(context.suggestionsDisplayCount - suggestions.count)
             .map { Autocomplete.Suggestion(text: $0, type: .regular) }
         
         suggestions.append(contentsOf: dictionarySuggestions)
         
         // Add autocorrect suggestion if needed
         if let autocorrect = findClosestMatch(for: text), autocorrect != text {
             suggestions.insert(Autocomplete.Suggestion(text: autocorrect, type: .autocorrect), at: 0)
         }
         
//         // Combine suggestions with the existing input
//         if tokenizedWords.count > 1 {
//             var prefix = tokenizedWords.dropLast().joined(separator: "")
//             if prefix.count > 10 { prefix = "" }
//             suggestions = suggestions.map { suggestion in
//                 Autocomplete.Suggestion(
//                     text: prefix + suggestion.text,
//                     type: suggestion.type
//                 )
//             }
//         }
         
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

