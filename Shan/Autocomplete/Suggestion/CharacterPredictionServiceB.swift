//
//  CharacterPredictionServiceB.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 12/9/2568 BE.
//

import Foundation
import KeyboardKit

class CharacterPredictionServiceB {
    
    private let dataManager: AutocompleteDataManager
    private let shanLanguageService: ShanLanguageService
    private let dictionaryService: DictionaryService
    private let characterChainOrder = 5
    
    // Character frequencies based on the analyzed text
    let characterFrequencies: [String: Double] = [
        "ႇ": 0.18,    // High frequency tone marker
        "ၼ": 0.12,    // High frequency consonant
        "း": 0.10,    // High frequency tone marker
        "ၵ": 0.09,    // High frequency consonant
        "ႈ": 0.08,    // High frequency tone marker
        "မ": 0.07,    // Medium frequency consonant
        "တ": 0.06,    // Medium frequency consonant
        "လ": 0.06,    // Medium frequency consonant
        "ဝ": 0.05,    // Medium frequency consonant
        "ႉ": 0.05,    // Medium frequency tone marker
        "ၶ": 0.04,    // Medium frequency consonant
        "ၸ": 0.04,    // Medium frequency consonant
        "င": 0.03,    // Lower frequency consonant
        "ပ": 0.03     // Lower frequency consonant
    ]
    
    init(dataManager: AutocompleteDataManager, dictionaryService: DictionaryService, shanLanguageService: ShanLanguageService) {
        self.dataManager = dataManager
        self.dictionaryService = dictionaryService
        self.shanLanguageService = shanLanguageService
    }
    
    /**
     Predicts the next character based on current input context
     
     - Parameter inputText: The current text input
     - Returns: Array of predicted characters sorted by probability (most likely first)
     */
    
    func getSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        let predictedCharacters: [String] = predictNextCharacter(for: text)
        guard !predictedCharacters.isEmpty else { return [] }
        
        var suggestions: [Autocomplete.Suggestion] = []

        for suggestion in predictedCharacters {
            suggestions.append(Autocomplete.Suggestion(text: suggestion, type: .unknown))
        }
        
        return suggestions
    }
    
    func predictNextCharacter(for inputText: String) -> [String] {
        guard !inputText.isEmpty else {
            // If empty, return most common word starters
            return getWordStarterCharacters()
        }
        
        let currentWord = getCurrentIncompleteWord(from: inputText)
        let lastChar = getLastCharacter(from: inputText)
        let syllableState = analyzeSyllableState(currentWord)
        
        var predictions: [String: Double] = [:]
        
        // Context-based prediction
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
        
        // Filter and validate predictions using dictionary
        let validatedPredictions = validatePredictionsWithDictionary(
            predictions: predictions,
            currentWord: currentWord
        )
        
        // Sort by probability and return top candidates
        return Array(validatedPredictions.keys)
            .sorted { validatedPredictions[$0] ?? 0 > validatedPredictions[$1] ?? 0 }
            .prefix(10)
            .map { $0 }
    }
    
    func getNextCharacterPredictions(for text: String) -> [Character: Double] {
        var predictions: [Character: Double] = [:]
        
        // Use character-level Markov chain for next character prediction
        let contextLength = min(characterChainOrder, text.count)
        if contextLength > 0 {
            let context = String(text.suffix(contextLength))
            
            if let nextChars = dataManager.characterMarkovChain[context] {
                let total = Double(nextChars.values.reduce(0, +))
                if total > 0 {
                    for (char, count) in nextChars {
                        if let character = char.first {
                            predictions[character] = Double(count) / total
                        }
                    }
                }
            }
        }
        
        // Fallback to general character frequency
        if predictions.isEmpty {
            for (char, count) in dataManager.userCharacterFrequency {
                if let character = char.first {
                    predictions[character] = Double(count)
                }
            }
            
            let total = predictions.values.reduce(0, +)
            if total > 0 {
                predictions = predictions.mapValues { $0 / total }
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
        case needsToneMark      // After consonant+vowel combination
        case needsVowel         // After initial consonant
        case needsFinalConsonant // After vowel, can add final consonant
        case completeCanContinue // Complete syllable, can add more or tone
        case shouldStartNewWord  // Should start new word/syllable
    }
    
    private func analyzeSyllableState(_ word: String) -> SyllableState {
        guard !word.isEmpty else { return .shouldStartNewWord }
        
        let lastChar = String(word.suffix(1))
        let hasConsonant = word.contains { shanLanguageService.shanConsonants.contains(String($0)) }
        let hasVowel = word.contains { shanLanguageService.shanVowels.contains(String($0)) }
        let hasToneMark = word.contains { shanLanguageService.shanToneMarks.contains(String($0)) }
        let hasFinalConsonant = word.contains { shanLanguageService.finalConsonants.contains(String($0)) }
        
        // If has tone mark, syllable is likely complete
        if hasToneMark || hasFinalConsonant {
            return .shouldStartNewWord
        }
        
        // If has consonant and vowel but no tone mark
        if hasConsonant && hasVowel {
            return .needsToneMark
        }
        
        // If has only consonant
        if hasConsonant && !hasVowel {
            return .needsVowel
        }
        
        // If has vowel, might need final consonant or tone
        if hasVowel {
            return .needsFinalConsonant
        }
        
        return .shouldStartNewWord
    }
    
    private func getToneMarkPredictions(for word: String) -> [String: Double] {
        var predictions: [String: Double] = [:]
        
        // Prioritize most common tone marks
        predictions["ႇ"] = 0.4  // Most frequent
        predictions["း"] = 0.25  // Second most frequent
        predictions["ႈ"] = 0.2   // Third most frequent
        predictions["ႉ"] = 0.1   // Less frequent
        predictions["ႊ"] = 0.05  // Least frequent
        
        return predictions
    }
    
    private func getVowelPredictions(for word: String) -> [String: Double] {
        var predictions: [String: Double] = [:]
        
        // Common vowel patterns
        let commonVowels = ["ိ", "ီ", "ု", "ူ", "ေ", "ၢ", "ႃ", "ွ"]
        
        for vowel in commonVowels {
            predictions[vowel] = 0.1 // Base probability
        }
        
        // Boost probability for very common vowels
        predictions["ိ"] = 0.2
        predictions["ီ"] = 0.15
        predictions["ု"] = 0.15
        predictions["ူ"] = 0.15
        
        return predictions
    }
    
    private func getFinalConsonantPredictions(for word: String) -> [String: Double] {
        var predictions: [String: Double] = [:]
        
        // Add final consonants with base probability
        for finalCons in shanLanguageService.finalConsonants {
            predictions[finalCons] = 0.1
        }
        
        // Boost common final consonants
        predictions["ၼ်"] = 0.25  // Very common
        predictions["င်"] = 0.2   // Common
        predictions["မ်"] = 0.15  // Common
        
        // Also consider tone marks as alternatives
        predictions.merge(getToneMarkPredictions(for: word)) { $0 + $1 * 0.5 }
        
        return predictions
    }
    
    private func getContinuationPredictions(for word: String, lastChar: String) -> [String: Double] {
        var predictions: [String: Double] = [:]
        
        // If last character is a tone mark or final consonant, likely to start new syllable
        if shanLanguageService.shanToneMarks.contains(lastChar) || shanLanguageService.finalConsonants.contains(lastChar) {
            return getNewWordPredictions()
        }
        
        // Otherwise, suggest tone marks or continuation
        predictions = getToneMarkPredictions(for: word)
        predictions.merge(getFinalConsonantPredictions(for: word)) { $0 + $1 * 0.3 }
        
        return predictions
    }
    
    private func getNewWordPredictions() -> [String: Double] {
        var predictions: [String: Double] = [:]
        
        // Use character frequencies for new word starts
        for (char, freq) in characterFrequencies {
            if shanLanguageService.shanConsonants.contains(char) {
                predictions[char] = freq
            }
        }
        
        return predictions
    }
    
    private func getWordStarterCharacters() -> [String] {
        // Return most common consonants for word starts
        return ["မ", "တ", "လ", "ၵ", "ၼ", "ပ", "သ", "ယ", "ဝ", "ဢ"]
    }
    
    private func validatePredictionsWithDictionary(
        predictions: [String: Double],
        currentWord: String
    ) -> [String: Double] {
        var validatedPredictions: [String: Double] = [:]
        
        for (char, probability) in predictions {
            let testWord = currentWord + char
            
            // Check if the new combination is valid
            if dictionaryService.isValidWord(testWord) {
                // Boost probability for dictionary matches
                validatedPredictions[char] = probability * 1.5
            } else {
                // Check if it could be part of a valid word (prefix matching)
                if couldBeValidWordPrefix(testWord) {
                    validatedPredictions[char] = probability
                } else {
                    // Reduce probability for unlikely combinations
                    validatedPredictions[char] = probability * 0.3
                }
            }
        }
        
        // Ensure we always have some predictions
        if validatedPredictions.isEmpty {
            return predictions
        }
        
        return validatedPredictions
    }
    
    private func couldBeValidWordPrefix(_ prefix: String) -> Bool {
        // Check if any word in common words starts with this prefix
        return shanLanguageService.commonShanWords.contains { $0.hasPrefix(prefix) }
        // You could also implement a more sophisticated prefix check
        // by querying the dictionary service for potential matches
    }
}

// MARK: - Usage Extension
extension CharacterPredictionServiceB {
    
    /**
     Convenience method to get top N predictions
     */
    func getTopPredictions(for inputText: String, limit: Int = 5) -> [String] {
        let predictions = predictNextCharacter(for: inputText)
        return Array(predictions.prefix(limit))
    }
    
    /**
     Get prediction with confidence scores
     */
    func getPredictionsWithConfidence(for inputText: String) -> [(character: String, confidence: Double)] {
        let predictions = predictNextCharacter(for: inputText)
        let total = Double(predictions.count)
        
        return predictions.enumerated().map { index, char in
            let confidence = (total - Double(index)) / total
            return (character: char, confidence: confidence)
        }
    }
}

