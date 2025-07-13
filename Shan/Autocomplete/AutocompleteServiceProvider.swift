//
//  AutocompleteServiceProvider.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import Foundation
import KeyboardKit

class AutocompleteServiceProvider: AutocompleteService {
    init(context: AutocompleteContext) {
        self.context = context
        loadUserSyllables()
        loadDictionaryWords()
        loadIgnoredWords()
        loadLearnedWords()
        buildCharacterMarkovChain()
        buildSyllableMarkovChain()
        buildBigramChain()
    }

    private var context: AutocompleteContext
    private var userSyllableFrequency: [String: Int] = [:]
    private var userCharacterFrequency: [String: Int] = [:]
    private var dictionaryWords: Set<String> = []
    private var currentInput: String = ""
    private var recentCharacters: [String] = []
    private var recentSyllables: [String] = []
    
    // Markov chains for different levels
    private var characterMarkovChain: [String: [String: Int]] = [:]
    private var syllableMarkovChain: [String: [String: Int]] = [:]
    private var bigramChain: [String: [String: Int]] = [:]
    
    private let characterChainOrder = 3
    private let syllableChainOrder = 2
    private let maxRecentCharacters = 20
    private let maxRecentSyllables = 10
    private let suggestionCache = NSCache<NSString, NSArray>()
    
    // Shan language specific characters and patterns
    private let shanVowels: Set = ["ႃ", "ၢ", "ႄ", "ႅ", "ေ", "ဵ", "ိ", "ီ", "ု", "ူ", "ႆ", "ႂ", "်", "ွ", "ျ", "ြ"]
    private let shanConsonants: Set = ["ၵ", "ၷ", "ၶ", "ꧠ", "င", "ၸ", "ၹ", "သ", "ၺ", "တ", "ၻ", "ထ", "ၼ", "ꧣ", "ပ", "ၽ", "ၾ", "ပ", "ၿ", "ႀ", "မ", "ယ", "ရ", "႟", "လ", "ꩮ", "ဝ", "ႁ", "ဢ"]
    private let shanToneMarks: Set = ["ႇ", "ႈ", "း", "ႉ", "ႊ"]
    
    var locale: Locale = .current
    
    var canIgnoreWords: Bool { true }
    var canLearnWords: Bool { true }
    var ignoredWords: [String] = []
    var learnedWords: [String] = []
    
    func hasIgnoredWord(_ word: String) -> Bool { ignoredWords.contains(word) }
    func hasLearnedWord(_ word: String) -> Bool { learnedWords.contains(word) }
    
    func ignoreWord(_ word: String) {
        ignoredWords.append(word)
        saveIgnoredWords()
    }
    
    func learnWord(_ word: String) {
        guard !word.isEmpty else { return }
        
        // Learn the complete word/phrase
        if !learnedWords.contains(word) {
            learnedWords.append(word)
        }
        
        // Break into syllables and learn patterns
        let syllables = extractSyllables(from: word)
        for syllable in syllables {
            incrementSyllableFrequency(syllable)
        }
        
        // Learn character patterns
        let characters = Array(word).map(String.init)
        for char in characters {
            incrementCharacterFrequency(char)
        }
        
        // Update Markov chains
        updateMarkovChains(with: word)
        
        saveLearnedWords()
    }
    
    func removeIgnoredWord(_ word: String) {
        ignoredWords.removeAll { $0 == word }
        saveIgnoredWords()
    }
    
    func unlearnWord(_ word: String) {
        learnedWords.removeAll { $0 == word }
        
        // Remove syllable frequencies
        let syllables = extractSyllables(from: word)
        for syllable in syllables {
            if let count = userSyllableFrequency[syllable], count > 1 {
                userSyllableFrequency[syllable] = count - 1
            } else {
                userSyllableFrequency[syllable] = nil
            }
        }
        
        saveLearnedWords()
        saveUserSyllables()
    }
    
    func autocompleteSuggestions(
        for text: String
    ) async throws -> [Autocomplete.Suggestion] {
        guard !text.isEmpty else { return [] }
        
        updateCurrentInput(with: text)
        
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
        var predictions: [Character: Double] = [:]
        
        // Use character-level Markov chain for next character prediction
        let contextLength = min(characterChainOrder, text.count)
        if contextLength > 0 {
            let context = String(text.suffix(contextLength))
            
            if let nextChars = characterMarkovChain[context] {
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
            for (char, count) in userCharacterFrequency {
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
    
    private func getSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        var suggestions: [Autocomplete.Suggestion] = []
        let maxSuggestions = max(3, context.suggestionsDisplayCount) // Ensure at least 3 suggestions
        
        // 1. Word completion from learned words (highest priority)
        let wordSuggestions = getWordCompletionSuggestions(for: text)
        suggestions.append(contentsOf: wordSuggestions)
        
        // 2. Syllable-level predictions
        if suggestions.count < maxSuggestions {
            let syllableSuggestions = getSyllableLevelSuggestions(for: text)
            suggestions.append(contentsOf: syllableSuggestions)
        }
        
        // 3. Character-level predictions (immediate next characters)
        if suggestions.count < maxSuggestions {
            let characterSuggestions = getCharacterLevelSuggestions(for: text)
            suggestions.append(contentsOf: characterSuggestions)
        }
        
        // 4. Dictionary word suggestions
        if suggestions.count < maxSuggestions {
            let dictionarySuggestions = getDictionarySuggestions(for: text)
            suggestions.append(contentsOf: dictionarySuggestions)
        }
        
        // 5. Contextual suggestions using bigram/trigram
        if suggestions.count < maxSuggestions {
            let contextualSuggestions = getContextualSuggestions(for: text)
            suggestions.append(contentsOf: contextualSuggestions)
        }
        
        // Remove duplicates and limit results
        let uniqueSuggestions = removeDuplicates(from: suggestions)
        
        // Ensure we have at least 3 suggestions by adding fallback suggestions
        let finalSuggestions = Array(uniqueSuggestions.prefix(maxSuggestions))
        
//        if finalSuggestions.count < 3 {
//            // Add fallback suggestions
//            let fallbackSuggestions = getFallbackSuggestions(for: text, excluding: Set(finalSuggestions.map { $0.text }))
//            finalSuggestions.append(contentsOf: fallbackSuggestions)
//        }
        
        return Array(finalSuggestions.prefix(maxSuggestions))
    }
    
    // MARK: - Character Level Suggestions
    
    private func getCharacterLevelSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        var suggestions: [Autocomplete.Suggestion] = []
        
        // Get next character predictions based on recent context
        let contextLength = min(characterChainOrder, text.count)
        if contextLength > 0 {
            let context = String(text.suffix(contextLength))
            
            if let nextChars = characterMarkovChain[context] {
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
            
            // Add common character combinations based on Shan patterns
            var commonContinuations: [String] = []
            
            if shanConsonants.contains(lastChar) {
                commonContinuations = ["ိ", "ီ", "ု", "ူ", "ေ", "ျ", "ြ"]
            } else if shanVowels.contains(lastChar) {
                commonContinuations = ["ႇ", "ႈ", "း", "ၵ", "တ", "ပ"]
            }
            
            for continuation in commonContinuations.prefix(3) {
                let suggestion = text + continuation
                suggestions.append(Autocomplete.Suggestion(text: suggestion, type: .unknown))
            }
        }
        
        return suggestions
    }
    
    // MARK: - Syllable Level Suggestions
    
    private func getSyllableLevelSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        var suggestions: [Autocomplete.Suggestion] = []
        
        // Try to complete current syllable
        let currentSyllable = extractCurrentSyllable(from: text)
        
        // Find syllables that start with current input
        let matchingSyllables = userSyllableFrequency
            .filter { $0.key.hasPrefix(currentSyllable) && $0.key != currentSyllable }
            .sorted { $0.value > $1.value }
            .prefix(5)
        
        for (syllable, _) in matchingSyllables {
            let suggestion = String(text.dropLast(currentSyllable.count)) + syllable
            suggestions.append(Autocomplete.Suggestion(text: suggestion, type: .unknown))
        }
        
        // Predict next syllable based on context
        if !recentSyllables.isEmpty {
            let contextLength = min(syllableChainOrder - 1, recentSyllables.count)
            let context = recentSyllables.suffix(contextLength).joined()
            
            if let nextSyllables = syllableMarkovChain[context] {
                let sortedSyllables = nextSyllables.sorted { $0.value > $1.value }
                
                for (syllable, _) in sortedSyllables.prefix(3) {
                    let suggestion = text + syllable
                    suggestions.append(Autocomplete.Suggestion(text: suggestion, type: .unknown))
                }
            }
        }
        
        return suggestions
    }
    
    // MARK: - Word completion from learned words
    
    private func getWordCompletionSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        return learnedWords
            .filter { $0.hasPrefix(text) && $0 != text }
            .sorted { word1, word2 in
                let freq1 = userSyllableFrequency[word1] ?? 0
                let freq2 = userSyllableFrequency[word2] ?? 0
                if freq1 != freq2 {
                    return freq1 > freq2
                }
                return word1.count < word2.count // Prefer shorter words if same frequency
            }
            .prefix(5)
            .map { Autocomplete.Suggestion(text: $0, type: .regular) }
    }
    
    // MARK: - Dictionary word suggestions
    
    private func getDictionarySuggestions(for text: String) -> [Autocomplete.Suggestion] {
        return dictionaryWords
            .filter { $0.hasPrefix(text) && $0 != text && !ignoredWords.contains($0) }
            .sorted { $0.count < $1.count } // Prefer shorter completions
            .prefix(5)
            .map { Autocomplete.Suggestion(text: $0, type: .regular) }
    }
    
    // MARK: - Contextual suggestions using bigram/trigram
    
    private func getContextualSuggestions(for text: String) -> [Autocomplete.Suggestion] {
        var suggestions: [Autocomplete.Suggestion] = []
        
        // Use bigram model for word-level prediction
        if let lastWord = getLastCompleteWord(from: text) {
            if let nextWords = bigramChain[lastWord] {
                let sortedWords = nextWords.sorted { $0.value > $1.value }
                let currentIncomplete = getCurrentIncompleteWord(from: text)
                
                for (word, _) in sortedWords.prefix(5) {
                    if word.hasPrefix(currentIncomplete) {
                        suggestions.append(Autocomplete.Suggestion(text: word, type: .regular))
                    }
                }
            }
        }
        
        return suggestions
    }
    
    // MARK: - Fallback suggestions
    
    private func getFallbackSuggestions(for text: String, excluding: Set<String>) -> [Autocomplete.Suggestion] {
        var suggestions: [Autocomplete.Suggestion] = []
        
        // Add common Shan words/syllables as fallbacks
        let commonShanWords = ["ၸၢင်ႈ", "မိူင်း", "ၵုင်း", "ပွၼ်", "လွင်ႈ", "ထၢမ်", "ၸိုင်ႈ", "ပီ", "ႁူဝ်", "ၸႂ်"]
        
        for word in commonShanWords {
            if word.hasPrefix(text) && !excluding.contains(word) {
                suggestions.append(Autocomplete.Suggestion(text: word, type: .regular))
                if suggestions.count >= 3 { break }
            }
        }
        
        // If still not enough, add simple character extensions
        if suggestions.count < 3 && !text.isEmpty {
            let commonExtensions = ["း", "ႈ", "ႇ", "ိ", "ီ", "ု", "ူ"]
            for ext in commonExtensions {
                let suggestion = text + ext
                if !excluding.contains(suggestion) {
                    suggestions.append(Autocomplete.Suggestion(text: suggestion, type: .unknown))
                    if suggestions.count >= 3 { break }
                }
            }
        }
        
        return suggestions
    }
    
    private func extractSyllables(from text: String) -> [String] {
        var syllables: [String] = []
        var currentSyllable = ""
        let chars = Array(text)
        
        for (index, char) in chars.enumerated() {
            let charStr = String(char)
            currentSyllable += charStr
            
            // Simple syllable boundary detection for Shan
            if shanVowels.contains(charStr) || shanToneMarks.contains(charStr) {
                // Look ahead to see if we should end the syllable
                let nextIndex = index + 1
                if nextIndex < chars.count {
                    let nextChar = String(chars[nextIndex])
                    if shanConsonants.contains(nextChar) && !shanToneMarks.contains(nextChar) {
                        syllables.append(currentSyllable)
                        currentSyllable = ""
                    }
                } else {
                    // End of text
                    syllables.append(currentSyllable)
                    currentSyllable = ""
                }
            }
        }
        
        if !currentSyllable.isEmpty {
            syllables.append(currentSyllable)
        }
        
        return syllables.isEmpty ? [text] : syllables
    }
    
    private func extractCurrentSyllable(from text: String) -> String {
        let syllables = extractSyllables(from: text)
        return syllables.last ?? text
    }
    
    private func getLastCompleteWord(from text: String) -> String? {
        // For Shan, we might consider punctuation or specific markers as word boundaries
        let components = text.components(separatedBy: CharacterSet(charactersIn: " ။၊\n\t"))
        let filtered = components.filter { !$0.isEmpty }
        return filtered.count >= 2 ? filtered[filtered.count - 2] : nil
    }
    
    private func getCurrentIncompleteWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet(charactersIn: " ။၊\n\t"))
        return components.last?.trimmingCharacters(in: .whitespaces) ?? ""
    }
    
    private func buildCharacterMarkovChain() {
        characterMarkovChain.removeAll()
        
        // Build from learned words and user syllables
        let allTexts = learnedWords + Array(userSyllableFrequency.keys)
        
        for text in allTexts {
            let chars = Array(text).map(String.init)
            
            for i in 0..<chars.count - 1 {
                for order in 1...min(characterChainOrder, chars.count - i - 1) {
                    let startIndex = max(0, i - order + 1)
                    let context = chars[startIndex...i].joined()
                    let nextChar = chars[i + 1]
                    characterMarkovChain[context, default: [:]][nextChar, default: 0] += 1
                }
            }
        }
    }
    
    private func buildSyllableMarkovChain() {
        syllableMarkovChain.removeAll()
        
        for text in learnedWords {
            let syllables = extractSyllables(from: text)
            
            for i in 0..<syllables.count - 1 {
                for order in 1...min(syllableChainOrder, syllables.count - i - 1) {
                    let startIndex = max(0, i - order + 1)
                    let context = syllables[startIndex...i].joined()
                    let nextSyllable = syllables[i + 1]
                    syllableMarkovChain[context, default: [:]][nextSyllable, default: 0] += 1
                }
            }
        }
    }
    
    private func buildBigramChain() {
        bigramChain.removeAll()
        
        for text in learnedWords {
            let words = text.components(separatedBy: CharacterSet(charactersIn: " ။၊\n\t"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            for i in 0..<words.count - 1 {
                bigramChain[words[i], default: [:]][words[i + 1], default: 0] += 1
            }
        }
    }
    
    private func updateMarkovChains(with text: String) {
        // Update character chain
        let chars = Array(text).map(String.init)
        for i in 0..<chars.count - 1 {
            for order in 1...min(characterChainOrder, chars.count - i - 1) {
                let startIndex = max(0, i - order + 1)
                let context = chars[startIndex...i].joined()
                let nextChar = chars[i + 1]
                characterMarkovChain[context, default: [:]][nextChar, default: 0] += 1
            }
        }
        
        // Update syllable chain
        let syllables = extractSyllables(from: text)
        for i in 0..<syllables.count - 1 {
            for order in 1...min(syllableChainOrder, syllables.count - i - 1) {
                let startIndex = max(0, i - order + 1)
                let context = syllables[startIndex...i].joined()
                let nextSyllable = syllables[i + 1]
                syllableMarkovChain[context, default: [:]][nextSyllable, default: 0] += 1
            }
        }
        
        // Update bigram chain
        let words = text.components(separatedBy: CharacterSet(charactersIn: " ။၊\n\t"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        for i in 0..<words.count - 1 {
            bigramChain[words[i], default: [:]][words[i + 1], default: 0] += 1
        }
    }
    
    private func updateCurrentInput(with text: String) {
        currentInput = text
        
        // Update recent characters
        let chars = Array(text).map(String.init)
        for char in chars {
            if recentCharacters.isEmpty || char != recentCharacters.last {
                recentCharacters.append(char)
                if recentCharacters.count > maxRecentCharacters {
                    recentCharacters.removeFirst()
                }
            }
        }
        
        // Update recent syllables
        let syllables = extractSyllables(from: text)
        for syllable in syllables {
            if recentSyllables.isEmpty || syllable != recentSyllables.last {
                recentSyllables.append(syllable)
                if recentSyllables.count > maxRecentSyllables {
                    recentSyllables.removeFirst()
                }
            }
        }
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
    
    private func incrementSyllableFrequency(_ syllable: String) {
        userSyllableFrequency[syllable, default: 0] += 1
        saveUserSyllables()
    }
    
    private func incrementCharacterFrequency(_ character: String) {
        userCharacterFrequency[character, default: 0] += 1
    }
    
    private func loadUserSyllables() {
        userSyllableFrequency = UserDefaults.standard.object(forKey: "UserSyllableFrequency") as? [String: Int] ?? [:]
        userCharacterFrequency = UserDefaults.standard.object(forKey: "UserCharacterFrequency") as? [String: Int] ?? [:]
    }
    
    private func saveUserSyllables() {
        UserDefaults.standard.set(userSyllableFrequency, forKey: "UserSyllableFrequency")
        UserDefaults.standard.set(userCharacterFrequency, forKey: "UserCharacterFrequency")
    }
    
    private func loadDictionaryWords() {
        if let path = Bundle.main.path(forResource: "dictionary", ofType: "txt"),
           let content = try? String(contentsOfFile: path) {
            dictionaryWords = Set(content.components(separatedBy: .newlines)
                .filter { !$0.isEmpty })
        }
    }
    
    private func loadIgnoredWords() {
        ignoredWords = UserDefaults.standard.object(forKey: "IgnoredWords") as? [String] ?? []
    }
    
    private func saveIgnoredWords() {
        UserDefaults.standard.set(ignoredWords, forKey: "IgnoredWords")
    }
    
    private func loadLearnedWords() {
        learnedWords = UserDefaults.standard.object(forKey: "LearnedWords") as? [String] ?? []
    }
    
    private func saveLearnedWords() {
        UserDefaults.standard.set(learnedWords, forKey: "LearnedWords")
    }
}

// MARK: - Extension for Shan language specific learning
extension AutocompleteServiceProvider {
    /// Call this when user types a character to learn patterns
    func userDidTypeCharacter(_ character: String) {
        incrementCharacterFrequency(character)
        
        // Update character context
        if recentCharacters.count >= characterChainOrder {
            let context = recentCharacters.suffix(characterChainOrder - 1).joined()
            characterMarkovChain[context, default: [:]][character, default: 0] += 1
        }
    }
    
    /// Call this when user completes a syllable
    func userDidCompleteSyllable(_ syllable: String) {
        incrementSyllableFrequency(syllable)
        
        // Update syllable context
        if recentSyllables.count >= syllableChainOrder {
            let context = recentSyllables.suffix(syllableChainOrder - 1).joined()
            syllableMarkovChain[context, default: [:]][syllable, default: 0] += 1
        }
    }
    
    /// Call this when user selects a suggestion
    func userDidSelectSuggestion(_ suggestion: Autocomplete.Suggestion) {
        learnWord(suggestion.text)
    }
    
    /// Call this when user completes typing a phrase/sentence
    func userDidCompletePhrase(_ phrase: String) {
        learnWord(phrase)
        
        // Build bigram for phrase-level prediction
        let words = phrase.components(separatedBy: CharacterSet(charactersIn: " ။၊\n\t"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        for i in 0..<words.count - 1 {
            bigramChain[words[i], default: [:]][words[i + 1], default: 0] += 1
        }
    }
}
