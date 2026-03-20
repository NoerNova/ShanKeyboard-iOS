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
    private let ngramService: NGramService

    /// Set by the view controller so the provider can retrigger autocomplete
    /// after the NGram model finishes loading on the background queue.
    var onNgramModelLoaded: (() -> Void)?

    private var dictionaryService: DictionaryService {
        SharedResources.shared.dictionaryService
    }

    // MARK: - Properties
    static var isSensitiveTextField = false
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
        self.ngramService = NGramService()

        self.wordCompletion = WordCompletionService(dataManager: dataManager)
        self.characterPrediction = CharacterPredictionService(dataManager: dataManager)
        self.contextualService = ContextualSuggestionService(dataManager: dataManager, ngramService: ngramService)
        self.spellCorrection = SpellCorrectionService()

        suggestionCache.countLimit = 100

        dataManager.loadAllData()
        ngramService.loadAsync { [weak self] in
            // Invalidate cache so next request uses the newly loaded model,
            // then retrigger autocomplete so the display updates immediately
            // without requiring the user to dismiss and reopen the keyboard.
            self?.suggestionCache.removeAllObjects()
            self?.onNgramModelLoaded?()
        }
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
        guard !Self.isSensitiveTextField else { return }
        dataManager.learnWord(word)
    }

    func removeIgnoredWord(_ word: String) {
        dataManager.removeIgnoredWord(word)
    }

    func unlearnWord(_ word: String) {
        dataManager.unlearnWord(word)
    }

    func autocomplete(_ text: String) async throws -> Autocomplete.ServiceResult {
        // When text is empty but context exists, show next-word predictions.
        // When text is empty and context is empty, nothing to show.
        if text.isEmpty && dataManager.contextWindow.isEmpty {
            return Autocomplete.ServiceResult(
                inputText: text,
                suggestions: [],
                emojiSuggestions: [],
                nextCharacterPredictions: [:]
            )
        }

        let cacheKey = "\(text)||\(dataManager.contextWindow.joined(separator: "|"))" as NSString
        if let cached = suggestionCache.object(forKey: cacheKey) {
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

        suggestionCache.setObject(CachedServiceResult(result), forKey: cacheKey)
        return result
    }

    // MARK: - Main Suggestion Logic
    //
    // Three fixed slots, matching native iOS suggestion bar layout:
    //   Slot 1 (left)   — personal: word the user has typed/learned before
    //   Slot 2 (middle) — NGram: best context-aware next-word prediction
    //   Slot 3 (right)  — dictionary: top frequency match
    //
    // Each slot gets the best candidate from its source that hasn't already
    // been claimed by an earlier slot. Fallbacks fill any remaining gaps.
    private func getSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        let maxSuggestions = max(3, context.settings.suggestionsDisplayCount)

        // --- Gather candidates from each source ---
        let personalCandidates  = wordCompletion.getSuggestions(for: text)
        let ngramCandidates     = contextualService.getSuggestions(for: text)
        let dictionaryCandidates = dictionaryService.getDictionarySuggestions(for: text)

        // Fallbacks used only to fill remaining gaps
        let syllableCandidates  = dictionaryService.getSyllableSuggestions(for: text)
        let spellCandidates: [Autocomplete.Suggestion] = (!text.isEmpty
            && !dictionaryService.isValidWord(text)
            && !dictionaryService.couldBeValidWordPrefix(text))
            ? spellCorrection.getSuggestions(for: text) : []

        // --- Assign slots ---
        var seen = Set<String>()
        var ordered: [Autocomplete.Suggestion] = []

        func pickFirst(from candidates: [Autocomplete.Suggestion]) {
            if let s = candidates.first(where: { !seen.contains($0.text) }) {
                ordered.append(s)
                seen.insert(s.text)
            }
        }

        pickFirst(from: personalCandidates)   // slot 1
        pickFirst(from: ngramCandidates)       // slot 2
        pickFirst(from: dictionaryCandidates)  // slot 3

        // Fill any remaining slots with fallbacks
        for s in (ngramCandidates + dictionaryCandidates + syllableCandidates + spellCandidates) {
            guard ordered.count < maxSuggestions else { break }
            if !seen.contains(s.text) {
                ordered.append(s)
                seen.insert(s.text)
            }
        }

        return deduplicateSuggestions(ordered, inputText: text)
    }

    private func deduplicateSuggestions(_ suggestions: [Autocomplete.Suggestion], inputText: String) -> [Autocomplete.Suggestion] {
        var seen = Set<String>()
        var result: [Autocomplete.Suggestion] = []

        let inputIsValid = !inputText.isEmpty && dictionaryService.isValidWord(inputText) && inputText.count > 2
        let currentWord = SharedResources.shared.shanLanguageService.getCurrentWord(from: inputText)

        for suggestion in suggestions {
            guard suggestion.text != inputText else { continue }
            guard suggestion.text != currentWord else { continue }
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
        guard !Self.isSensitiveTextField else { return }
        dataManager.userDidTypeCharacter(character)
    }

    func userDidCompleteSyllable(_ syllable: String) {
        guard !Self.isSensitiveTextField else { return }
        dataManager.userDidCompleteSyllable(syllable)
    }

    func userDidSelectSuggestion(_ suggestion: Autocomplete.Suggestion) {
        guard !Self.isSensitiveTextField else { return }
        // learnWord is already called by KeyboardKit's tryAutolearnSuggestion → learn()
        dataManager.advanceContext(completedWord: suggestion.text)
        suggestionCache.removeAllObjects()
    }

    func userDidCompletePhrase(_ phrase: String) {
        guard !Self.isSensitiveTextField else { return }
        dataManager.userDidCompletePhrase(phrase)

        // Advance context for each word in the phrase
        let words = phrase.components(separatedBy: " ").filter { !$0.isEmpty }
        for word in words { dataManager.advanceContext(completedWord: word) }
        suggestionCache.removeAllObjects()
    }

    func userDidCompleteSentence() {
        dataManager.resetContextAtSentenceBoundary()
        suggestionCache.removeAllObjects()
    }

    /// Called on every `textDidChange` — derives context from the raw document text.
    /// `partialWord` is `currentWordPreCursorPart`: the incomplete word being typed right now.
    /// It must be stripped before tokenising so it doesn't pollute the context window.
    func updateContextFromDocument(_ documentContext: String, partialWord: String) {
        guard !documentContext.isEmpty else {
            if !dataManager.contextWindow.isEmpty {
                dataManager.setContextWindow([])
                suggestionCache.removeAllObjects()
            }
            return
        }

        // Strip the partial word from the end using unicode scalars.
        // Grapheme-level comparison fails for Shan combining characters.
        let contextToTokenize: String
        if !partialWord.isEmpty {
            let docScalars  = Array(documentContext.unicodeScalars)
            let wordScalars = Array(partialWord.unicodeScalars)
            if docScalars.count >= wordScalars.count,
               Array(docScalars.suffix(wordScalars.count)) == wordScalars {
                contextToTokenize = String(String.UnicodeScalarView(docScalars.dropLast(wordScalars.count)))
            } else {
                contextToTokenize = documentContext
            }
        } else {
            contextToTokenize = documentContext
        }

        let tokens  = Tokenizer.shared.tokenize(contextToTokenize).filter { !$0.isEmpty }
        let lastTwo = Array(tokens.suffix(2))

        guard lastTwo != dataManager.contextWindow else { return }
        dataManager.setContextWindow(lastTwo)
        suggestionCache.removeAllObjects()
    }
}

// Wrapper for NSCache storage of ServiceResult
private class CachedServiceResult: NSObject {
    let result: Autocomplete.ServiceResult
    init(_ result: Autocomplete.ServiceResult) {
        self.result = result
    }
}
