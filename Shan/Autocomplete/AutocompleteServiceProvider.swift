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
    private let contextualService: ContextualSuggestionService
    private let spellCorrection: SpellCorrectionService
    private let dataManager: AutocompleteDataManager

    private var dictionaryService: DictionaryService {
        SharedResources.shared.dictionaryService
    }

    // MARK: - Properties
    private var context: AutocompleteContext
    // Bounded LRU cache via NSCache (auto-evicts)
    private var suggestionCache = NSCache<NSString, CachedServiceResult>()

    var locale: Locale = .current
    var canIgnoreWords: Bool { true }
    var canLearnWords: Bool { true }
    var ignoredWords: [String] { dataManager.ignoredWords }
    var learnedWords: [String] { dataManager.learnedWords }

    // MARK: - Initialization
    init(context: AutocompleteContext) {
        self.context = context
        self.dataManager = AutocompleteDataManager()

        self.wordCompletion = WordCompletionService(dataManager: dataManager)
        self.characterPrediction = CharacterPredictionService(dataManager: dataManager)
        self.contextualService = ContextualSuggestionService(dataManager: dataManager)
        self.spellCorrection = SpellCorrectionService()

        suggestionCache.countLimit = 100

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
                nextCharacterPredictions: [:]
            )
        }

        let key = text as NSString
        if let cached = suggestionCache.object(forKey: key) {
            return cached.result
        }

        let suggestions = getSuggestions(for: text)
        let characterPredictions = characterPrediction.getNextCharacterPredictions(for: text)

        let result = Autocomplete.ServiceResult(
            inputText: text,
            suggestions: suggestions,
            emojiSuggestions: [],
            nextCharacterPredictions: characterPredictions
        )

        suggestionCache.setObject(CachedServiceResult(result), forKey: key)
        return result
    }

    // MARK: - Main Suggestion Logic
    private func getSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        let maxSuggestions = max(3, context.settings.suggestionsDisplayCount)
        var allSuggestions: [Autocomplete.Suggestion] = []

        // 1. Word completion from learned words (highest priority)
        allSuggestions.append(contentsOf: wordCompletion.getSuggestions(for: text))

        // 2. Dictionary word suggestions
        if allSuggestions.count < maxSuggestions {
            let dicSuggestions = dictionaryService.getDictionarySuggestions(for: text)
            allSuggestions.append(contentsOf: dicSuggestions)
        }

        // 3. Contextual next-word suggestions (bigram-based)
        if allSuggestions.count < maxSuggestions {
            allSuggestions.append(contentsOf: contextualService.getSuggestions(for: text))
        }

        // 4. Syllable-level predictions
        if allSuggestions.count < maxSuggestions {
            allSuggestions.append(contentsOf: dictionaryService.getSyllableSuggestions(for: text))
        }

        // 5. Spell correction (when input is not a valid word/prefix)
        if allSuggestions.count < maxSuggestions && !dictionaryService.isValidWord(text) && !dictionaryService.couldBeValidWordPrefix(text) {
            allSuggestions.append(contentsOf: spellCorrection.getSuggestions(for: text))
        }

        // 6. Character-level predictions (disabled — not useful yet as standalone suggestions)
//         if allSuggestions.count < maxSuggestions && !dictionaryService.isValidWord(text) {
//             allSuggestions.append(contentsOf: characterPrediction.getSuggestions(for: text))
//         }

        // Deduplicate at the end
        let deduplicated = deduplicateSuggestions(allSuggestions, inputText: text)
        return Array(deduplicated.prefix(maxSuggestions))
    }

    private func deduplicateSuggestions(_ suggestions: [Autocomplete.Suggestion], inputText: String) -> [Autocomplete.Suggestion] {
        var seen = Set<String>()
        var result: [Autocomplete.Suggestion] = []

        let inputIsValid = !inputText.isEmpty && dictionaryService.isValidWord(inputText) && inputText.count > 2

        for suggestion in suggestions {
            guard suggestion.text != inputText else { continue }
            // Reject grammatically invalid suggestions
            guard ShanGrammarRules.isGrammaticallyValid(suggestion.text) else { continue }

            let completionText = determineCompletionText(for: suggestion, inputText: inputText, inputIsValid: inputIsValid)

            guard let completion = completionText, !completion.isEmpty, !seen.contains(completion) else { continue }
            guard ShanGrammarRules.isGrammaticallyValid(completion) else { continue }

            seen.insert(completion)
            result.append(
                Autocomplete.Suggestion(
                    text: completion,
                    type: suggestion.type,
                    source: suggestion.source
                )
            )
        }

        return result
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

// Wrapper for NSCache storage of ServiceResult
private class CachedServiceResult: NSObject {
    let result: Autocomplete.ServiceResult
    init(_ result: Autocomplete.ServiceResult) {
        self.result = result
    }
}
