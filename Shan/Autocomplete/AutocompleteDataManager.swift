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

    // MARK: - Personal bigram chain (rebuilt from learnedWordsList at load)
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

    // MARK: - Size limits
    // Learned data used to grow forever: every accepted suggestion and every
    // completed phrase was appended, then loaded, re-tokenized and indexed on
    // each keyboard launch. These caps keep it bounded. Oldest learned words
    // and rarest syllables are dropped first.
    static let maxLearnedWords = 3_000
    static let maxSyllableEntries = 4_000

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
        buildBigramChain()
    }

    /// Re-derives the word bigram chain from learned words. Must run again after the
    /// tokenizer's backing dictionary loads — at loadAllData() time the tokenizer
    /// returns [] for everything, so the chain built there is always empty.
    func rebuildBigramChain() {
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
            trimLearnedWords()
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
    }

    func userDidCompletePhrase(_ phrase: String) {
        learnWord(phrase)

        let words = parseWordsFromText(phrase)
        addBigrams(words)
    }

    /// Search learned words by prefix using trie (O(prefix length + results))
    func searchLearnedWords(prefix: String, limit: Int = 5) -> [(word: String, frequency: Int)] {
        guard let node = learnedWordsTrie.searchPrefix(prefix) else { return [] }
        return node.getAllWords(prefix: prefix, limit: limit)
    }

    // MARK: - Private Helper Methods
    private func incrementSyllableFrequency(_ syllable: String) {
        userSyllableFrequency[syllable, default: 0] += 1
        trimSyllableFrequency()
        debounceSaveSyllables()
    }

    /// Drops the oldest learned words beyond maxLearnedWords.
    private func trimLearnedWords() {
        let excess = learnedWordsList.count - Self.maxLearnedWords
        guard excess > 0 else { return }
        for word in learnedWordsList.prefix(excess) {
            learnedWordsSet.remove(word)
            learnedWordsTrie.remove(word)
        }
        learnedWordsList.removeFirst(excess)
    }

    /// Keeps the most frequent maxSyllableEntries syllables. Prunes in one batch
    /// once the map is 10% over the cap, so the sort runs rarely.
    private func trimSyllableFrequency() {
        guard userSyllableFrequency.count > Self.maxSyllableEntries + Self.maxSyllableEntries / 10 else { return }
        let keep = userSyllableFrequency
            .sorted { $0.value > $1.value }
            .prefix(Self.maxSyllableEntries)
        userSyllableFrequency = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
    }

    private func parseWordsFromText(_ text: String) -> [String] {
        let tokens = Tokenizer.shared.tokenize(text)
        return tokens.filter { !$0.isEmpty }
    }

    // MARK: - Bigram Chain Building
    /// Counts each adjacent word pair. Safe for 0 or 1 words: the old
    /// `0..<words.count - 1` loop trapped on an empty array, which happened on
    /// every cold launch with learned words because the tokenizer returns []
    /// until the dictionary has loaded.
    private func addBigrams(_ words: [String]) {
        for (current, next) in zip(words, words.dropFirst()) {
            bigramChain[current, default: [:]][next, default: 0] += 1
        }
    }

    private func buildBigramChain() {
        bigramChain.removeAll()

        for text in learnedWordsList {
            let words = parseWordsFromText(text)
            addBigrams(words)
        }
    }

    private func updateMarkovChains(with text: String) {
        let words = parseWordsFromText(text)
        addBigrams(words)
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
        trimSyllableFrequency()
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
        let stored = UserDefaults.standard.object(forKey: "LearnedWords") as? [String] ?? []
        learnedWordsList = Array(stored.suffix(Self.maxLearnedWords))
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
