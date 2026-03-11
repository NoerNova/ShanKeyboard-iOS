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
        let currentWord = SharedResources.shared.shanLanguageService.getCurrentWord(from: text)
        let prefix: String
        if !currentWord.isEmpty {
            prefix = currentWord
        } else {
            prefix = Tokenizer.shared.getLastToken(from: text) ?? text
        }
        return getWordCompletionSuggestions(for: prefix)
    }

    private func getWordCompletionSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        // Use trie-based lookup instead of linear scan
        let matches = dataManager.searchLearnedWords(prefix: text, limit: 5)
        return matches
            .filter { $0.word != text }
            .map { Autocomplete.Suggestion(text: $0.word, type: .regular) }
    }
}
