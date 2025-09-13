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
    private let characterPrediction: CharacterPredictionServiceB
    private let dictionaryService: DictionaryService
    private let contextualService: ContextualSuggestionService
    private let dataManager: AutocompleteDataManager
    private let shanLanguageService: ShanLanguageService
    
    // MARK: - Properties
    private var context: AutocompleteContext
    private var suggestionCache: [String: Autocomplete.ServiceResult] = [:]
    
    var locale: Locale = .current
    var canIgnoreWords: Bool { true }
    var canLearnWords: Bool { true }
    var ignoredWords: [String] { dataManager.ignoredWords }
    var learnedWords: [String] { dataManager.learnedWords }
    
    // MARK: - Initialization
    init(context: AutocompleteContext) {
        self.context = context
        self.dataManager = AutocompleteDataManager()
        self.dictionaryService = DictionaryService()
        self.shanLanguageService = ShanLanguageService()
        self.wordCompletion = WordCompletionService(dataManager: dataManager)
//        self.characterPrediction = CharacterPredictionService(
//            dataManager: dataManager,
//            shanService: shanLanguageService
//        )
        self.characterPrediction = CharacterPredictionServiceB(dataManager: dataManager, dictionaryService: dictionaryService, shanLanguageService: shanLanguageService)
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
    
    func autocomplete(_ text: String) async throws -> Autocomplete.ServiceResult {
        guard !text.isEmpty else {
            return Autocomplete.ServiceResult(
                inputText: text,
                suggestions: [],
                emojiSuggestions: [],
                nextCharacterPredictions: [:],
            )
        }
        
        // Check cache first
        if let cachedResult = suggestionCache[text] {
            return cachedResult
        }
        
        // Get suggestions
        let suggestions = getSuggestions(for: text)
        
        // Get character predictions
        let characterPredictions = characterPrediction.getNextCharacterPredictions(for: text)
        
        // Create result
        let result = Autocomplete.ServiceResult(
            inputText: text,
            suggestions: suggestions,
            emojiSuggestions: [],
            nextCharacterPredictions: characterPredictions,
        )
        
        // Cache the result
        suggestionCache[text] = result
        
        return result
    }
    
    // MARK: - Main Suggestion Logic
    private func getSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        var suggestions: [Autocomplete.Suggestion] = []
        let maxSuggestions = max(3, context.settings.suggestionsDisplayCount)
        
        // 1. Word completion from learned words (highest priority)
        suggestions.append(contentsOf: wordCompletion.getSuggestions(for: text))
        
        // 2. Dictionary word suggestions (prefer words over raw characters)
        if suggestions.count < maxSuggestions {
            let dicSuggestions = dictionaryService.getDictionarySuggestions(for: text)
            let uniqueSuggestions = removeDuplicatesAndInputText(from: dicSuggestions, inputText: text)
            suggestions.append(contentsOf: Array(uniqueSuggestions.prefix(maxSuggestions)))
        }
        
        // 3. Syllable-level predictions
        if suggestions.count < maxSuggestions {
            suggestions.append(contentsOf: dictionaryService.getSyllableSuggestions(for: text))
        }
        
//        // 4. Contextual next-word suggestions (bigram-based)
//        if suggestions.count < maxSuggestions {
//            suggestions.append(contentsOf: contextualService.getSuggestions(for: text))
//        }
//
//
//        // 5. Character-level predictions (fallback only)
//        // Character predictions can be noisy for Shan; keep as last resort.
//        if suggestions.count < maxSuggestions && !dictionaryService.isValidWord(text) {
//            suggestions.append(contentsOf: characterPrediction.getSuggestions(for: text))
//        }

        return suggestions
    }
    
    private func removeDuplicatesAndInputText(from suggestions: [Autocomplete.Suggestion], inputText: String) -> [Autocomplete.Suggestion] {
        var seen = Set<String>()
        var processedSuggestions: [Autocomplete.Suggestion] = []
        
        let inputIsValid = !inputText.isEmpty && dictionaryService.isValidWord(inputText) && inputText.count > 2

        for suggestion in suggestions {
            guard suggestion.text != inputText else { continue }
            
            let completionText = determineCompletionText(for: suggestion, inputText: inputText, inputIsValid: inputIsValid)
            
            guard let completion = completionText, !completion.isEmpty, !seen.contains(completion) else { continue }
            
            seen.insert(completion)
            processedSuggestions.append(
                Autocomplete.Suggestion(
                    text: completion,
                    type: suggestion.type,
                    source: suggestion.source
                )
            )
        }

        return processedSuggestions
    }

    private func determineCompletionText(for suggestion: Autocomplete.Suggestion, inputText: String, inputIsValid: Bool) -> String? {
        guard inputIsValid else {
            return suggestion.text
        }
        
        if dictionaryService.isValidWord(suggestion.text) {
            return processValidSuggestion(suggestion.text, inputText: inputText)
        }
        
        return suggestion.text
    }

    private func processValidSuggestion(_ suggestionText: String, inputText: String) -> String {
        guard suggestionText.hasPrefix(inputText), suggestionText.count > inputText.count else {
            return suggestionText
        }
        
        let dropped = String(suggestionText.dropFirst(inputText.count))
        guard dropped.count >= 1 else { return suggestionText }
        
        // Tokenize the dropped part and take the first token for more natural completion
        let droppedTokens = Tokenizer.shared.tokenize(dropped)
        let firstToken = droppedTokens.first ?? dropped
        
        return dictionaryService.isValidWord(firstToken) ? firstToken : suggestionText
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
