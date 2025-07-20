//
//  CharacterPredictionService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 20/7/2568 BE.
//

import Foundation
import KeyboardKit

class CharacterPredictionService {
    
    private let dataManager: AutocompleteDataManager
    private let shanService: ShanLanguageService
    private let characterChainOrder = 3
    
    init(dataManager: AutocompleteDataManager, shanService: ShanLanguageService) {
        self.dataManager = dataManager
        self.shanService = shanService
    }
    
    func getSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        return getCharacterLevelSuggestions(for: text)
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
    
    private func getCharacterLevelSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        var suggestions: [Autocomplete.Suggestion] = []
        
        // Get next character predictions based on recent context
        let contextLength = min(characterChainOrder, text.count)
        if contextLength > 0 {
            let context = String(text.suffix(contextLength))
            
            if let nextChars = dataManager.characterMarkovChain[context] {
                let sortedChars = nextChars.sorted { $0.value > $1.value }
                
                for (char, _) in sortedChars.prefix(3) {
                    let suggestion = text + char
                    suggestions.append(Autocomplete.Suggestion(text: suggestion, type: .unknown))
                }
            }
        }
        
        // Fallback: common character continuations
        if suggestions.isEmpty && !text.isEmpty {
            let lastChar = String(text.last!)
            let commonContinuations = shanService.getCommonContinuations(for: lastChar)
            
            for continuation in commonContinuations.prefix(3) {
                let suggestion = text + continuation
                suggestions.append(Autocomplete.Suggestion(text: suggestion, type: .unknown))
            }
        }
        
        return suggestions
    }
}
