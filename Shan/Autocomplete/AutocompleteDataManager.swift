//
//  AutocompleteDataManager.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 20/7/2568 BE.
//

import Foundation

class AutocompleteDataManager {
    
    // MARK: - Core Data Properties
    private(set) var userSyllableFrequency: [String: Int] = [:]
    private(set) var userCharacterFrequency: [String: Int] = [:]
    private(set) var ignoredWords: [String] = []
    private(set) var learnedWords: [String] = []
    
    // MARK: - Markov Chains
    private(set) var characterMarkovChain: [String: [String: Int]] = [:]
    private(set) var syllableMarkovChain: [String: [String: Int]] = [:]
    private(set) var bigramChain: [String: [String: Int]] = [:]
    
    // MARK: - Context Tracking
    private(set) var recentCharacters: [String] = []
    private(set) var recentSyllables: [String] = []
    
    // MARK: - Constants
    private let characterChainOrder = 3
    private let syllableChainOrder = 2
    private let maxRecentCharacters = 20
    private let maxRecentSyllables = 10
    
    // MARK: - Services
    private let shanLanguageService = ShanLanguageService()
    
    // MARK: - Public Interface
    func loadAllData() {
        loadUserSyllables()
        loadIgnoredWords()
        loadLearnedWords()
        buildCharacterMarkovChain()
        buildSyllableMarkovChain()
        buildBigramChain()
    }
    
    func hasIgnoredWord(_ word: String) -> Bool {
        ignoredWords.contains(word)
    }
    
    func hasLearnedWord(_ word: String) -> Bool {
        learnedWords.contains(word)
    }
    
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
        let syllables = shanLanguageService.extractSyllables(from: word)
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
        let syllables = shanLanguageService.extractSyllables(from: word)
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
    
    // MARK: - User Learning Methods
    func userDidTypeCharacter(_ character: String) {
        incrementCharacterFrequency(character)
        updateRecentCharacters(with: character)
        
        // Update character context
        if recentCharacters.count >= characterChainOrder {
            let context = recentCharacters.suffix(characterChainOrder - 1).joined()
            characterMarkovChain[context, default: [:]][character, default: 0] += 1
        }
    }
    
    func userDidCompleteSyllable(_ syllable: String) {
        incrementSyllableFrequency(syllable)
        updateRecentSyllables(with: syllable)
        
        // Update syllable context
        if recentSyllables.count >= syllableChainOrder {
            let context = recentSyllables.suffix(syllableChainOrder - 1).joined()
            syllableMarkovChain[context, default: [:]][syllable, default: 0] += 1
        }
    }
    
    func userDidCompletePhrase(_ phrase: String) {
        learnWord(phrase)
        
        // Build bigram for phrase-level prediction
        let words = parseWordsFromText(phrase)
        for i in 0..<words.count - 1 {
            bigramChain[words[i], default: [:]][words[i + 1], default: 0] += 1
        }
    }
    
    func updateCurrentInput(with text: String) {
        // Update recent characters
        let chars = Array(text).map(String.init)
        for char in chars {
            updateRecentCharacters(with: char)
        }
        
        // Update recent syllables
        let syllables = shanLanguageService.extractSyllables(from: text)
        for syllable in syllables {
            updateRecentSyllables(with: syllable)
        }
    }
    
    // MARK: - Private Helper Methods
    private func incrementSyllableFrequency(_ syllable: String) {
        userSyllableFrequency[syllable, default: 0] += 1
        saveUserSyllables()
    }
    
    private func incrementCharacterFrequency(_ character: String) {
        userCharacterFrequency[character, default: 0] += 1
    }
    
    private func updateRecentCharacters(with character: String) {
        if recentCharacters.isEmpty || character != recentCharacters.last {
            recentCharacters.append(character)
            if recentCharacters.count > maxRecentCharacters {
                recentCharacters.removeFirst()
            }
        }
    }
    
    private func updateRecentSyllables(with syllable: String) {
        if recentSyllables.isEmpty || syllable != recentSyllables.last {
            recentSyllables.append(syllable)
            if recentSyllables.count > maxRecentSyllables {
                recentSyllables.removeFirst()
            }
        }
    }
    
    private func parseWordsFromText(_ text: String) -> [String] {
        // Use the Shan tokenizer to split text into words, since Shan has no spaces
        let tokens = Tokenizer.shared.tokenize(text)
        return tokens.filter { !$0.isEmpty }
    }
    
    // MARK: - Markov Chain Building
    private func buildCharacterMarkovChain() {
        characterMarkovChain.removeAll()
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
            let syllables = shanLanguageService.extractSyllables(from: text)
            
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
            let words = parseWordsFromText(text)
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
        let syllables = shanLanguageService.extractSyllables(from: text)
        for i in 0..<syllables.count - 1 {
            for order in 1...min(syllableChainOrder, syllables.count - i - 1) {
                let startIndex = max(0, i - order + 1)
                let context = syllables[startIndex...i].joined()
                let nextSyllable = syllables[i + 1]
                syllableMarkovChain[context, default: [:]][nextSyllable, default: 0] += 1
            }
        }
        
        // Update bigram chain
        let words = parseWordsFromText(text)
        for i in 0..<words.count - 1 {
            bigramChain[words[i], default: [:]][words[i + 1], default: 0] += 1
        }
    }
    
    // MARK: - Persistence
    private func loadUserSyllables() {
        userSyllableFrequency = UserDefaults.standard.object(forKey: "UserSyllableFrequency") as? [String: Int] ?? [:]
        userCharacterFrequency = UserDefaults.standard.object(forKey: "UserCharacterFrequency") as? [String: Int] ?? [:]
    }
    
    private func saveUserSyllables() {
        UserDefaults.standard.set(userSyllableFrequency, forKey: "UserSyllableFrequency")
        UserDefaults.standard.set(userCharacterFrequency, forKey: "UserCharacterFrequency")
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
