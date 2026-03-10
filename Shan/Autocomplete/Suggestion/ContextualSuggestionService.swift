//
//  ContextualSuggestionService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 20/7/2568 BE.
//

import Foundation
import KeyboardKit

class ContextualSuggestionService {

    private let dataManager: AutocompleteDataManager

    private var shanService: ShanLanguageService {
        SharedResources.shared.shanLanguageService
    }

    private var dictionaryService: DictionaryService {
        SharedResources.shared.dictionaryService
    }

    init(dataManager: AutocompleteDataManager) {
        self.dataManager = dataManager
    }

    func getSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        var suggestions: [Autocomplete.Suggestion] = []

        suggestions.append(contentsOf: getContextualSuggestions(for: text))

        if suggestions.count < 3 {
            suggestions.append(contentsOf: getFallbackSuggestions(
                for: text,
                excluding: Set(suggestions.map { $0.text })
            ))
        }

        return suggestions
    }

    private func getContextualSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        var results: [Autocomplete.Suggestion] = []

        guard let contextToken = shanService.getLastCompleteWord(from: text),
              let candidates = dataManager.bigramChain[contextToken] else {
            return results
        }

        let partialNext = shanService.getCurrentIncompleteWord(from: text)

        let sorted = candidates.sorted { $0.value > $1.value }
        for (next, _) in sorted.prefix(10) {
            if !partialNext.isEmpty && !next.hasPrefix(partialNext) { continue }
            results.append(Autocomplete.Suggestion(text: next, type: .regular))
            if results.count >= 5 { break }
        }

        return results
    }

    private func getFallbackSuggestions(for text: String, excluding: Set<String>) -> [Autocomplete.Suggestion] {
        var suggestions: [Autocomplete.Suggestion] = []

        // Use top-frequency words from dictionary instead of hardcoded list
        let topWords = dictionaryService.topWords
        for word in topWords {
            if word.hasPrefix(text) && !excluding.contains(word) {
                suggestions.append(Autocomplete.Suggestion(text: word, type: .regular))
                if suggestions.count >= 3 { break }
            }
        }

        // Append extensions only if grammatically valid after last character
        if suggestions.count < 3 && !text.isEmpty {
            let lastChar = String(text.suffix(1))
            let commonExtensions = shanService.getCommonExtensions()
            for ext in commonExtensions {
                // Use grammar rules to filter invalid extensions
                guard ShanGrammarRules.canFollow(current: lastChar, next: ext) else { continue }

                let suggestion = text + ext
                if !excluding.contains(suggestion) && dictionaryService.couldBeValidWordPrefix(suggestion) {
                    suggestions.append(Autocomplete.Suggestion(text: suggestion, type: .unknown))
                    if suggestions.count >= 3 { break }
                }
            }
        }

        return suggestions
    }
}
