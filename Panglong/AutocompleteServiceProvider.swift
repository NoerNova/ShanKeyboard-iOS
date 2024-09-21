//
//  FakeAutocompleteService.swift
//  Panglong_iKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import Foundation
import KeyboardKit

/// This fake service provides fake suggestions while typing.
class AutocompleteServiceProvider: AutocompleteService {

    init(context: AutocompleteContext) {
        self.context = context
    }

    private var context: AutocompleteContext
    
    var locale: Locale = .current
    
    var canIgnoreWords: Bool { false }
    var canLearnWords: Bool { false }
    var ignoredWords: [String] = []
    var learnedWords: [String] = []
    
    func hasIgnoredWord(_ word: String) -> Bool { false }
    func hasLearnedWord(_ word: String) -> Bool { false }
    func ignoreWord(_ word: String) {}
    func learnWord(_ word: String) {}
    func removeIgnoredWord(_ word: String) {}
    func unlearnWord(_ word: String) {}
    
    func autocompleteSuggestions(
        for text: String
    ) async throws -> [Autocomplete.Suggestion] {
        guard text.count > 0 else { return [] }
        return fakeSuggestions(for: text)
            .map {
                let autocorrect = $0.isAutocorrect && context.isAutocorrectEnabled
                var suggestion = $0
                suggestion.type = autocorrect ? .autocorrect : $0.type
                return suggestion
            }
    }

    func nextCharacterPredictions(
        forText text: String,
        suggestions: [Autocomplete.Suggestion]
    ) async throws -> [Character : Double] {
        [:]
    }
}

private extension AutocompleteServiceProvider {

    func fakeSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        let suggestions: [Autocomplete.Suggestion] = [
            .init(text: text, type: .unknown),
            .init(text: text, type: .autocorrect),
            .init(text: text, subtitle: "Subtitle"),
        ]
        return Array(suggestions.prefix(context.suggestionsDisplayCount))
    }
}
