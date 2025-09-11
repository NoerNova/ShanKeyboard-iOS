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
    private let shanService = ShanLanguageService()
    
    init(dataManager: AutocompleteDataManager) {
        self.dataManager = dataManager
    }
    
    func getSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        var suggestions: [Autocomplete.Suggestion] = []
        
        // Contextual suggestions using bigram/trigram
        suggestions.append(contentsOf: getContextualSuggestions(for: text))
        
        // Fallback suggestions if needed
        if suggestions.count < 3 {
            suggestions.append(contentsOf: getFallbackSuggestions(for: text, excluding: Set(suggestions.map { $0.text })))
        }
        
        return suggestions
    }
    
    private func getContextualSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        var results: [Autocomplete.Suggestion] = []

        // Determine context: last complete token for bigram lookup.
        guard let contextToken = shanService.getLastCompleteWord(from: text),
              let candidates = dataManager.bigramChain[contextToken] else {
            return results
        }

        // If the user already started the next token, filter by that prefix.
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
        
        // Add common Shan words/syllables as fallbacks
        for word in shanService.commonShanWords {
            if word.hasPrefix(text) && !excluding.contains(word) {
                suggestions.append(Autocomplete.Suggestion(text: word, type: .regular))
                if suggestions.count >= 3 { break }
            }
        }
        
        // If still not enough, add simple character extensions
        if suggestions.count < 3 && !text.isEmpty {
            let commonExtensions = shanService.getCommonExtensions()
            for ext in commonExtensions {
                let suggestion = text + ext
                if !excluding.contains(suggestion) {
                    suggestions.append(Autocomplete.Suggestion(text: suggestion, type: .unknown))
                    if suggestions.count >= 3 { break }
                }
            }
        }
        
        return suggestions
    }
}
