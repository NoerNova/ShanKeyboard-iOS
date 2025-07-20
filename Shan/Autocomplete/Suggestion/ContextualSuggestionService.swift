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
        var suggestions: [Autocomplete.Suggestion] = []
        
        // Use bigram model for word-level prediction
        if let lastWord = shanService.getLastCompleteWord(from: text) {
            if let nextWords = dataManager.bigramChain[lastWord] {
                let sortedWords = nextWords.sorted { $0.value > $1.value }
                let currentIncomplete = shanService.getCurrentIncompleteWord(from: text)
                
                for (word, _) in sortedWords.prefix(5) {
                    if word.hasPrefix(currentIncomplete) {
                        suggestions.append(Autocomplete.Suggestion(text: word, type: .regular))
                    }
                }
            }
        }
        
        return suggestions
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
