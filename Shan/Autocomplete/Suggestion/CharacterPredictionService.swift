//
//  CharacterPredictionService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 12/9/2568 BE.
//

import Foundation
import KeyboardKit

class CharacterPredictionService {

    private let dataManager: AutocompleteDataManager
    private let characterChainOrder = 5

    private var shanLanguageService: ShanLanguageService {
        SharedResources.shared.shanLanguageService
    }

    private var dictionaryService: DictionaryService {
        SharedResources.shared.dictionaryService
    }

    // Character frequencies based on analyzed Shan text
    let characterFrequencies: [String: Double] = [
        "ႇ": 0.18, "ၼ": 0.12, "း": 0.10, "ၵ": 0.09,
        "ႈ": 0.08, "မ": 0.07, "တ": 0.06, "လ": 0.06,
        "ဝ": 0.05, "ႉ": 0.05, "ၶ": 0.04, "ၸ": 0.04,
        "င": 0.03, "ပ": 0.03
    ]

    init(dataManager: AutocompleteDataManager) {
        self.dataManager = dataManager
    }

    func getSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        let currentWord = getCurrentIncompleteWord(from: text)

        // No suggestions if the word doesn't start with a consonant
        if let firstChar = currentWord.first.map(String.init),
           !ShanGrammarRules.consonants.contains(firstChar) {
            return []
        }

        let lastChar = String(currentWord.suffix(1))

        // After consonant+ၢ (e.g. မၢ): suggest dictionary words matching this prefix
        if lastChar == "ၢ" && currentWord.count >= 2 {
            let matches = dictionaryService.searchWords(prefix: currentWord, limit: 5)
            if !matches.isEmpty {
                return matches.map {
                    Autocomplete.Suggestion(text: $0.word, type: .unknown)
                }
            }
        }

        // When last char is a finalConsonantBase, build compound suggestions
        // e.g. "ၼမ" → suggest "ၼမ်", "ၼမ်း", "ၼမ်ႉ" etc.
        if ShanGrammarRules.finalConsonantBases.contains(lastChar) && currentWord.count >= 2 {
            var suggestions: [Autocomplete.Suggestion] = []
            let withAsat = text + ShanGrammarRules.asat

            // Base: word + ်
            suggestions.append(Autocomplete.Suggestion(text: withAsat, type: .unknown))

            // word + ် + each tone mark
            for tone in ["ႇ", "း", "ႈ", "ႉ", "ႊ"] {
                let withTone = withAsat + tone
                if dictionaryService.isValidWord(withTone) || dictionaryService.couldBeValidWordPrefix(withTone) {
                    suggestions.append(Autocomplete.Suggestion(text: withTone, type: .unknown))
                }
            }

            // If we got dictionary-backed results, return those; otherwise return top few
            if suggestions.count <= 1 {
                // Add tone mark variants even without dictionary backing
                for tone in ["ႇ", "း", "ႉ"] {
                    suggestions.append(Autocomplete.Suggestion(text: withAsat + tone, type: .unknown))
                }
            }

            return Array(suggestions.prefix(5))
        }

        let predictedCharacters = predictNextCharacter(for: text)
        return predictedCharacters.map {
            Autocomplete.Suggestion(text: $0, type: .unknown)
        }
    }

    func predictNextCharacter(for inputText: String) -> [String] {
        guard !inputText.isEmpty else {
            return getWordStarterCharacters()
        }

        let currentWord = getCurrentIncompleteWord(from: inputText)

        // No predictions if the word doesn't start with a consonant
        if let firstChar = currentWord.first.map(String.init),
           !ShanGrammarRules.consonants.contains(firstChar) {
            return []
        }

        let lastChar = getLastCharacter(from: inputText)
        let syllableState = analyzeSyllableState(currentWord)

        var predictions: [String: Double]
        switch syllableState {
        case .needsToneMark:
            predictions = getToneMarkPredictions(for: currentWord)
        case .needsVowel:
            predictions = getVowelPredictions(for: currentWord)
        case .needsFinalConsonant:
            predictions = getFinalConsonantPredictions(for: currentWord)
        case .completeCanContinue:
            predictions = getContinuationPredictions(for: currentWord, lastChar: lastChar)
        case .shouldStartNewWord:
            predictions = getNewWordPredictions()
        }

        let validatedPredictions = validatePredictionsWithDictionary(
            predictions: predictions,
            currentWord: currentWord
        )

        return Array(validatedPredictions.keys)
            .sorted { validatedPredictions[$0] ?? 0 > validatedPredictions[$1] ?? 0 }
            .prefix(10)
            .map { $0 }
    }

    func getNextCharacterPredictions(for text: String) -> [Character: Double] {
        var predictions: [Character: Double] = [:]

        // Use user character frequency data
        let freqData = dataManager.userCharacterFrequency
        if !freqData.isEmpty {
            let total = Double(freqData.values.reduce(0, +))
            if total > 0 {
                for (char, count) in freqData {
                    if let character = char.first {
                        predictions[character] = Double(count) / total
                    }
                }
            }
        }

        // Fallback to static character frequencies
        if predictions.isEmpty {
            for (char, freq) in characterFrequencies {
                if let character = char.first {
                    predictions[character] = freq
                }
            }
        }

        return predictions
    }

    // MARK: - Helper Functions

    private func getCurrentIncompleteWord(from text: String) -> String {
        let components = text.components(separatedBy: shanLanguageService.wordBoundaryCharacters)
        return components.last ?? ""
    }

    private func getLastCharacter(from text: String) -> String {
        return String(text.suffix(1))
    }

    private enum SyllableState {
        case needsToneMark
        case needsVowel
        case needsFinalConsonant
        case completeCanContinue
        case shouldStartNewWord
    }

    private func analyzeSyllableState(_ word: String) -> SyllableState {
        guard !word.isEmpty else { return .shouldStartNewWord }

        let chars = Array(word).map(String.init)
        let lastChar = chars.last!
        let expected = ShanGrammarRules.expectedNext(after: word)

        // If last char is a tone mark or asat → start new word
        if ShanGrammarRules.toneMarks.contains(lastChar) || lastChar == ShanGrammarRules.asat {
            return .shouldStartNewWord
        }

        // If expecting only consonant (new word), we're done
        if expected == [.consonant] {
            return .shouldStartNewWord
        }

        // Key rule: if last char is a finalConsonantBase AND there's already a preceding
        // consonant (with or without vowel), this consonant likely forms a final with ်.
        // e.g. "ၼမ" → "ၼမ်", "ၵိၼ" → "ၵိၼ်"
        if ShanGrammarRules.finalConsonantBases.contains(lastChar) && chars.count >= 2 {
            let preceding = chars[chars.count - 2]
            let precType = ShanGrammarRules.charType(of: preceding)
            // If preceded by a consonant, vowel, medial, or special vowel → likely forming final
            if precType == .consonant || precType == .vowel || precType == .medial ||
               precType == .specialVowelHoy || precType == .specialVowelGuaiTai || precType == .kaikhuen {
                return .needsFinalConsonant
            }
        }

        // After vowels that expect only finalConsonantBases (e.g., after ၢ, ို, ိူ)
        // expected has .consonant but no .toneMark and no .vowel
        if expected.contains(.consonant) && !expected.contains(.toneMark) &&
           !expected.contains(.vowel) && !expected.contains(.medial) {
            let lastType = ShanGrammarRules.charType(of: lastChar)
            if lastType == .vowel {
                return .needsFinalConsonant
            }
        }

        // If tone marks are expected but not vowels/medials → needs tone mark
        if expected.contains(.toneMark) && !expected.contains(.vowel) && !expected.contains(.medial) {
            return .needsToneMark
        }

        // If vowels/medials are expected → needs vowel
        if expected.contains(.vowel) || expected.contains(.medial) {
            return .needsVowel
        }

        // If we have a vowel and can take final consonants
        if expected.contains(.consonant) && expected.contains(.toneMark) {
            return .completeCanContinue
        }

        return .completeCanContinue
    }

    private func getToneMarkPredictions(for word: String) -> [String: Double] {
        return ["ႇ": 0.4, "း": 0.25, "ႈ": 0.2, "ႉ": 0.1, "ႊ": 0.05]
    }

    private func getVowelPredictions(for word: String) -> [String: Double] {
        var predictions: [String: Double] = [
            "ိ": 0.2, "ီ": 0.15, "ု": 0.15, "ူ": 0.15,
            "ေ": 0.1, "ၢ": 0.1, "ႃ": 0.1, "ွ": 0.1
        ]

        // Offer medials only when they form valid clusters with the last consonant
        let lastChar = String(word.suffix(1))
        if ShanGrammarRules.consonants.contains(lastChar) {
            for medial in ShanGrammarRules.medials {
                if ShanGrammarRules.isValidCluster(consonant: lastChar, medial: medial) {
                    predictions[medial] = 0.12
                }
            }
        }

        return predictions
    }

    private func getFinalConsonantPredictions(for word: String) -> [String: Double] {
        var predictions: [String: Double] = [:]
        let lastChar = String(word.suffix(1))

        // If last char is already a finalConsonantBase (e.g. "ၼမ" → offer ် first)
        if ShanGrammarRules.finalConsonantBases.contains(lastChar) {
            predictions[ShanGrammarRules.asat] = 0.8  // ် is the most likely next char
            // Also offer tone marks that would follow the final (consonant+်+toneMark)
            for (tone, prob) in getToneMarkPredictions(for: word) {
                predictions[tone] = prob * 0.3  // lower weight since ် comes first
            }
        } else {
            // After a vowel: offer final consonant bases (they'll be followed by ်)
            for base in ShanGrammarRules.finalConsonantBases {
                predictions[base] = 0.1
            }
            predictions["ၼ"] = 0.25
            predictions["င"] = 0.2
            predictions["မ"] = 0.15

            // After ၢ: also offer ႆ, but no tone marks (ၢ requires final consonant first)
            if lastChar == "ၢ" {
                predictions["ႆ"] = 0.2
            } else {
                predictions.merge(getToneMarkPredictions(for: word)) { $0 + $1 * 0.5 }
            }
        }

        return predictions
    }

    private func getContinuationPredictions(for word: String, lastChar: String) -> [String: Double] {
        if shanLanguageService.shanToneMarks.contains(lastChar) || shanLanguageService.finalConsonants.contains(lastChar) {
            return getNewWordPredictions()
        }
        var predictions = getToneMarkPredictions(for: word)
        predictions.merge(getFinalConsonantPredictions(for: word)) { $0 + $1 * 0.3 }
        return predictions
    }

    private func getNewWordPredictions() -> [String: Double] {
        var predictions: [String: Double] = [:]
        for (char, freq) in characterFrequencies {
            if shanLanguageService.shanConsonants.contains(char) {
                predictions[char] = freq
            }
        }
        return predictions
    }

    private func getWordStarterCharacters() -> [String] {
        return ["မ", "တ", "လ", "ၵ", "ၼ", "ပ", "သ", "ယ", "ဝ", "ဢ"]
    }

    private func validatePredictionsWithDictionary(
        predictions: [String: Double],
        currentWord: String
    ) -> [String: Double] {
        var validatedPredictions: [String: Double] = [:]
        let lastChar = currentWord.isEmpty ? nil : String(currentWord.suffix(1))

        for (char, probability) in predictions {
            // Grammar filter: reject if canFollow returns false
            if let last = lastChar, !ShanGrammarRules.canFollow(current: last, next: char) {
                continue  // completely exclude invalid sequences
            }

            let testWord = currentWord + char

            if dictionaryService.isValidWord(testWord) {
                validatedPredictions[char] = probability * 1.5
            } else if dictionaryService.couldBeValidWordPrefix(testWord) {
                validatedPredictions[char] = probability
            } else {
                validatedPredictions[char] = probability * 0.3
            }
        }

        return validatedPredictions.isEmpty ? predictions : validatedPredictions
    }
}

// MARK: - Convenience Extensions
extension CharacterPredictionService {

    func getTopPredictions(for inputText: String, limit: Int = 5) -> [String] {
        return Array(predictNextCharacter(for: inputText).prefix(limit))
    }

    func getPredictionsWithConfidence(for inputText: String) -> [(character: String, confidence: Double)] {
        let predictions = predictNextCharacter(for: inputText)
        let total = Double(predictions.count)
        return predictions.enumerated().map { index, char in
            (character: char, confidence: (total - Double(index)) / total)
        }
    }
}
