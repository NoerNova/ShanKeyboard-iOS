//
//  WordCompletionService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 20/7/2568 BE.
//

import Foundation
import KeyboardKit

class WordCompletionService {
    
    private let dataManager: AutocompleteDataManager
    
    init(dataManager: AutocompleteDataManager) {
        self.dataManager = dataManager
    }
    
    func getSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        return getWordCompletionSuggestions(for: text)
    }
    
    private func getWordCompletionSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        return dataManager.learnedWords
            .filter { $0.hasPrefix(text) && $0 != text }
            .sorted { word1, word2 in
                let freq1 = dataManager.userSyllableFrequency[word1] ?? 0
                let freq2 = dataManager.userSyllableFrequency[word2] ?? 0
                if freq1 != freq2 {
                    return freq1 > freq2
                }
                return word1.count < word2.count // Prefer shorter words if same frequency
            }
            .prefix(5)
            .map { Autocomplete.Suggestion(text: $0, type: .regular) }
    }
}
