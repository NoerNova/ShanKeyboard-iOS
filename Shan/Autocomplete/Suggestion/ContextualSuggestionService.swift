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
    private let ngramService: NGramService?

    private var shanService: ShanLanguageService {
        SharedResources.shared.shanLanguageService
    }

    private var dictionaryService: DictionaryService {
        SharedResources.shared.dictionaryService
    }

    init(dataManager: AutocompleteDataManager, ngramService: NGramService? = nil) {
        self.dataManager = dataManager
        self.ngramService = ngramService
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

    // MARK: - NGram-backed contextual suggestions

    private func getContextualSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        // Use NGram model if loaded
        if let ngram = ngramService, ngram.isLoaded {
            return ngramContextualSuggestions(for: text, service: ngram)
        }
        return legacyGetContextualSuggestions(for: text)
    }

    private func ngramContextualSuggestions(
        for text: String,
        service: NGramService
    ) -> [Autocomplete.Suggestion] {

        // Normalise the same way DictionaryService does (getCurrentWord, not the
        // Tokenizer, which mis-splits incomplete trailing words).
        let partialNext = shanService.getCurrentWord(from: text)
        let context = dataManager.contextWindow  // up to 2 recent completed words

        // Prefix completions still come from the dictionary slot, and are appended
        // here as backup so compounds like မိူင်း→မိူင်းတႆး stay reachable.
        var results: [Autocomplete.Suggestion] = []
        if !partialNext.isEmpty, dictionaryService.isValidWord(partialNext) {
            let nextWordContext = Array((context + [partialNext]).suffix(2))
            results = service.scoredCandidates(
                context: nextWordContext,
                partialNext: "",
                userBigramChain: dataManager.bigramChain,
                limit: 5
            ).map { Autocomplete.Suggestion(text: $0.word, type: .regular) }
        }

        let candidates = service.scoredCandidates(
            context: context,
            partialNext: partialNext,
            userBigramChain: dataManager.bigramChain,
            limit: 10
        )

        results.append(contentsOf: candidates.map { Autocomplete.Suggestion(text: $0.word, type: .regular) })
        return results
    }

    // MARK: - Legacy fallback (user bigram chain only)

    private func legacyGetContextualSuggestions(for text: String) -> [Autocomplete.Suggestion] {
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

    // MARK: - Fallback suggestions (unigram frequency + grammar extensions)

    private func getFallbackSuggestions(for rawText: String, excluding: Set<String>) -> [Autocomplete.Suggestion] {
        var suggestions: [Autocomplete.Suggestion] = []

        let text = shanService.getCurrentWord(from: rawText)

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
            let lastChar = ShanGrammarRules.lastScalar(text) ?? ""
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
