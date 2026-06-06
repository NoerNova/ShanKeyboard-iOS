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
    private(set) var ignoredWordsSet: Set<String> = []
    private(set) var learnedWordsSet: Set<String> = []
    private(set) var learnedWordsList: [String] = []

    // Trie for prefix-based completion of learned words
    private(set) var learnedWordsTrie = TrieNode()

    // MARK: - Markov Chains
    private(set) var syllableMarkovChain: [String: [String: Int]] = [:]
    private(set) var bigramChain: [String: [String: Int]] = [:]

    // MARK: - Context Window (last 2 completed words, newest last)
    private(set) var contextWindow: [String] = []

    func advanceContext(completedWord: String) {
        guard !completedWord.isEmpty else { return }
        contextWindow.append(completedWord)
        if contextWindow.count > 2 { contextWindow.removeFirst() }
    }

    func setContextWindow(_ words: [String]) {
        contextWindow = words
    }

    func resetContextAtSentenceBoundary() {
        contextWindow.removeAll()
    }

    // MARK: - Context Tracking
    private(set) var recentSyllables: [String] = []

    // MARK: - Constants
    private let syllableChainOrder = 2
    private let maxRecentSyllables = 10

    // MARK: - Debounced Persistence
    private var syllableSaveTimer: Timer?
    private var learnedWordsSaveTimer: Timer?
    private let saveDebounceInterval: TimeInterval = 2.0

    // MARK: - Services
    private var shanLanguageService: ShanLanguageService {
        SharedResources.shared.shanLanguageService
    }

    // MARK: - Public Interface
    func loadAllData() {
        loadUserSyllables()
        loadIgnoredWords()
        loadLearnedWords()
        buildSyllableMarkovChain()
        buildBigramChain()
    }

    // Backward-compatible accessors
    var ignoredWords: [String] { Array(ignoredWordsSet) }
    var learnedWords: [String] { learnedWordsList }

    func hasIgnoredWord(_ word: String) -> Bool {
        ignoredWordsSet.contains(word)
    }

    func hasLearnedWord(_ word: String) -> Bool {
        learnedWordsSet.contains(word)
    }

    func ignoreWord(_ word: String) {
        ignoredWordsSet.insert(word)
        saveIgnoredWords()
    }

    func learnWord(_ word: String) {
        guard !word.isEmpty else { return }

        if !learnedWordsSet.contains(word) {
            learnedWordsSet.insert(word)
            learnedWordsList.append(word)
            learnedWordsTrie.insert(word, frequency: 1)
        }

        // Break into syllables and learn patterns
        let syllables = shanLanguageService.extractSyllables(from: word)
        for syllable in syllables {
            incrementSyllableFrequency(syllable)
        }

        // Update Markov chains
        updateMarkovChains(with: word)
        debounceSaveLearnedWords()
    }

    func removeIgnoredWord(_ word: String) {
        ignoredWordsSet.remove(word)
        saveIgnoredWords()
    }

    func unlearnWord(_ word: String) {
        learnedWordsSet.remove(word)
        learnedWordsList.removeAll { $0 == word }
        learnedWordsTrie.remove(word)

        let syllables = shanLanguageService.extractSyllables(from: word)
        for syllable in syllables {
            if let count = userSyllableFrequency[syllable], count > 1 {
                userSyllableFrequency[syllable] = count - 1
            } else {
                userSyllableFrequency[syllable] = nil
            }
        }

        debounceSaveLearnedWords()
        debounceSaveSyllables()
    }

    // MARK: - User Learning Methods
    func userDidTypeCharacter(_ character: String) {
        userCharacterFrequency[character, default: 0] += 1
    }

    func userDidCompleteSyllable(_ syllable: String) {
        incrementSyllableFrequency(syllable)
        updateRecentSyllables(with: syllable)

        if recentSyllables.count >= syllableChainOrder {
            let context = recentSyllables.suffix(syllableChainOrder - 1).joined()
            syllableMarkovChain[context, default: [:]][syllable, default: 0] += 1
        }
    }

    func userDidCompletePhrase(_ phrase: String) {
        learnWord(phrase)

        let words = parseWordsFromText(phrase)
        for i in 0..<words.count - 1 {
            bigramChain[words[i], default: [:]][words[i + 1], default: 0] += 1
        }
    }

    func updateCurrentInput(with text: String) {
        let syllables = shanLanguageService.extractSyllables(from: text)
        for syllable in syllables {
            updateRecentSyllables(with: syllable)
        }
    }

    /// Search learned words by prefix using trie (O(prefix length + results))
    func searchLearnedWords(prefix: String, limit: Int = 5) -> [(word: String, frequency: Int)] {
        guard let node = learnedWordsTrie.searchPrefix(prefix) else { return [] }
        return node.getAllWords(prefix: prefix, limit: limit)
    }

    // MARK: - Private Helper Methods
    private func incrementSyllableFrequency(_ syllable: String) {
        userSyllableFrequency[syllable, default: 0] += 1
        debounceSaveSyllables()
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
        let tokens = Tokenizer.shared.tokenize(text)
        return tokens.filter { !$0.isEmpty }
    }

    // MARK: - Markov Chain Building
    private func buildSyllableMarkovChain() {
        syllableMarkovChain.removeAll()

        for text in learnedWordsList {
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

        for text in learnedWordsList {
            let words = parseWordsFromText(text)
            for i in 0..<words.count - 1 {
                bigramChain[words[i], default: [:]][words[i + 1], default: 0] += 1
            }
        }
    }

    private func updateMarkovChains(with text: String) {
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

    // MARK: - Debounced Persistence
    private func debounceSaveSyllables() {
        syllableSaveTimer?.invalidate()
        syllableSaveTimer = Timer.scheduledTimer(withTimeInterval: saveDebounceInterval, repeats: false) { [weak self] _ in
            self?.saveUserSyllables()
        }
    }

    private func debounceSaveLearnedWords() {
        learnedWordsSaveTimer?.invalidate()
        learnedWordsSaveTimer = Timer.scheduledTimer(withTimeInterval: saveDebounceInterval, repeats: false) { [weak self] _ in
            self?.saveLearnedWords()
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
        let arr = UserDefaults.standard.object(forKey: "IgnoredWords") as? [String] ?? []
        ignoredWordsSet = Set(arr)
    }

    private func saveIgnoredWords() {
        UserDefaults.standard.set(Array(ignoredWordsSet), forKey: "IgnoredWords")
    }

    private func loadLearnedWords() {
        learnedWordsList = UserDefaults.standard.object(forKey: "LearnedWords") as? [String] ?? []
        learnedWordsSet = Set(learnedWordsList)

        // Build trie from learned words
        for word in learnedWordsList {
            let freq = userSyllableFrequency[word] ?? 1
            learnedWordsTrie.insert(word, frequency: freq)
        }
    }

    private func saveLearnedWords() {
        UserDefaults.standard.set(learnedWordsList, forKey: "LearnedWords")
    }
}
