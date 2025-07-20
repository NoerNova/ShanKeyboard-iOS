//
//  AutocompleteServiceProvider.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import Foundation
import KeyboardKit

class AutocompleteServiceProvider: AutocompleteService {
    
    // MARK: - Dependencies
    private let wordCompletion: WordCompletionService
    private let characterPrediction: CharacterPredictionService
    private let dictionaryService: DictionaryService
    private let contextualService: ContextualSuggestionService
    private let dataManager: AutocompleteDataManager
    private let shanLanguageService: ShanLanguageService
    
    // MARK: - Properties
    private var context: AutocompleteContext
    private let suggestionCache = NSCache<NSString, NSArray>()
    
    var locale: Locale = .current
    var canIgnoreWords: Bool { true }
    var canLearnWords: Bool { true }
    var ignoredWords: [String] { dataManager.ignoredWords }
    var learnedWords: [String] { dataManager.learnedWords }
    
    // MARK: - Initialization
    init(context: AutocompleteContext) {
        self.context = context
        self.dataManager = AutocompleteDataManager()
        self.shanLanguageService = ShanLanguageService()
        self.wordCompletion = WordCompletionService(dataManager: dataManager)
        self.characterPrediction = CharacterPredictionService(
            dataManager: dataManager,
            shanService: shanLanguageService
        )
        self.dictionaryService = DictionaryService()
        self.contextualService = ContextualSuggestionService(dataManager: dataManager)
        
        dataManager.loadAllData()
    }
    
    // MARK: - AutocompleteService Protocol
    func hasIgnoredWord(_ word: String) -> Bool {
        dataManager.hasIgnoredWord(word)
    }
    
    func hasLearnedWord(_ word: String) -> Bool {
        dataManager.hasLearnedWord(word)
    }
    
    func ignoreWord(_ word: String) {
        dataManager.ignoreWord(word)
    }
    
    func learnWord(_ word: String) {
        dataManager.learnWord(word)
    }
    
    func removeIgnoredWord(_ word: String) {
        dataManager.removeIgnoredWord(word)
    }
    
    func unlearnWord(_ word: String) {
        dataManager.unlearnWord(word)
    }
    
    func autocompleteSuggestions(
        for text: String
    ) async throws -> [Autocomplete.Suggestion] {
        guard !text.isEmpty else { return [] }
        
        // Check cache first
        let cacheKey = text as NSString
        if let cachedSuggestions = suggestionCache.object(forKey: cacheKey) as? [Autocomplete.Suggestion] {
            return cachedSuggestions
        }
        
        let suggestions = getSuggestions(for: text)
        suggestionCache.setObject(suggestions as NSArray, forKey: cacheKey)
        return suggestions
    }

    func nextCharacterPredictions(
        forText text: String,
        suggestions: [Autocomplete.Suggestion]
    ) async throws -> [Character : Double] {
        return characterPrediction.getNextCharacterPredictions(for: text)
    }
    
    // MARK: - Main Suggestion Logic
    private func getSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        var suggestions: [Autocomplete.Suggestion] = []
        let maxSuggestions = max(3, context.suggestionsDisplayCount)
        
        // 1. Word completion from learned words (highest priority)
        suggestions.append(contentsOf: wordCompletion.getSuggestions(for: text))
        
        // 2. Syllable-level predictions
        if suggestions.count < maxSuggestions {
            suggestions.append(contentsOf: dictionaryService.getSyllableSuggestions(for: text))
        }
        
        // 3. Character-level predictions
        // TODO: Should analyze Shan's gramma for next character suggestion
        if suggestions.count < maxSuggestions {
            suggestions.append(contentsOf: characterPrediction.getSuggestions(for: text))
        }
        
        // 4. Dictionary word suggestions
        if suggestions.count < maxSuggestions {
            suggestions.append(contentsOf: dictionaryService.getDictionarySuggestions(for: text))
        }
        
//        // 5. Contextual suggestions
//        if suggestions.count < maxSuggestions {
//            suggestions.append(contentsOf: contextualService.getSuggestions(for: text))
//        }
        
        // Remove duplicates and limit results
        let uniqueSuggestions = removeDuplicates(from: suggestions)
        return Array(uniqueSuggestions.prefix(maxSuggestions))
    }
    
    private func removeDuplicates(from suggestions: [Autocomplete.Suggestion]) -> [Autocomplete.Suggestion] {
        var seen = Set<String>()
        return suggestions.filter { suggestion in
            if seen.contains(suggestion.text) {
                return false
            }
            seen.insert(suggestion.text)
            return true
        }
    }
}

// MARK: - User Learning Extensions
extension AutocompleteServiceProvider {
    func userDidTypeCharacter(_ character: String) {
        dataManager.userDidTypeCharacter(character)
    }
    
    func userDidCompleteSyllable(_ syllable: String) {
        dataManager.userDidCompleteSyllable(syllable)
    }
    
    func userDidSelectSuggestion(_ suggestion: Autocomplete.Suggestion) {
        dataManager.learnWord(suggestion.text)
    }
    
    func userDidCompletePhrase(_ phrase: String) {
        dataManager.userDidCompletePhrase(phrase)
    }
}
