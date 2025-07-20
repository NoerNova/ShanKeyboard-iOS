//
//  Tokeinzer.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 24/9/2567 BE.
//

import Foundation

public class Tokenizer {
    
    private var dictionaryWords: Set<String> = []
    private var maxWordLength: Int = 0
    private var isLoaded = false
    
    // Cache for recent tokenizations to avoid repeated work
    private var tokenizationCache: [String: [String]] = [:]
    private let maxCacheSize = 50
    
    init() {
        loadDictionary()
    }
    
    private func loadDictionary() {
        guard let path = Bundle.main.path(forResource: "dictionary", ofType: "txt") else {
            print("Dictionary file not found")
            return
        }
        
        do {
            let content = try String(contentsOfFile: path)
            let words = content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            dictionaryWords = Set(words)
            maxWordLength = words.max(by: { $0.count < $1.count })?.count ?? 0
            isLoaded = true
            
            print("Dictionary loaded: \(dictionaryWords.count) words, max length: \(maxWordLength)")
        } catch {
            print("Error loading dictionary: \(error)")
        }
    }
    
    public func tokenize(_ text: String) -> [String] {
        guard isLoaded && !text.isEmpty else { return [] }
        
        // Check cache first
        if let cached = tokenizationCache[text] {
            return cached
        }
        
        let tokens = performTokenization(text)
        
        // Cache result with size management
        if tokenizationCache.count >= maxCacheSize {
            // Remove oldest entry (simple FIFO)
            if let firstKey = tokenizationCache.keys.first {
                tokenizationCache.removeValue(forKey: firstKey)
            }
        }
        tokenizationCache[text] = tokens
        
        return tokens
    }
    
    private func performTokenization(_ text: String) -> [String] {
        var words: [String] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            if let (word, nextIndex) = findLongestMatchOptimized(in: text, from: currentIndex) {
                words.append(word)
                currentIndex = nextIndex
            } else {
                // Handle unknown character - take single character
                let nextIndex = text.index(after: currentIndex)
                let singleChar = String(text[currentIndex..<nextIndex])
                words.append(singleChar)
                currentIndex = nextIndex
            }
        }
        
        return words
    }
    
    private func findLongestMatchOptimized(in text: String, from startIndex: String.Index) -> (String, String.Index)? {
        let remainingDistance = text.distance(from: startIndex, to: text.endIndex)
        let maxCheckLength = min(maxWordLength, remainingDistance)
        
        // Start from longest possible match and work backwards
        for length in stride(from: maxCheckLength, through: 1, by: -1) {
            guard let endIndex = text.index(startIndex, offsetBy: length, limitedBy: text.endIndex) else {
                continue
            }
            
            let candidate = String(text[startIndex..<endIndex])
            if dictionaryWords.contains(candidate) {
                return (candidate, endIndex)
            }
        }
        
        return nil
    }
    
    
    // For keyboard extension - tokenize only the last few characters for efficiency
    public func tokenizeLastPart(_ text: String, maxLength: Int = 100) -> [String] {
        let processText = text.count > maxLength ? String(text.suffix(maxLength)) : text
        return tokenize(processText)
    }
    
    // Quick check if a word exists in dictionary
    public func wordExists(_ word: String) -> Bool {
        return dictionaryWords.contains(word)
    }
    
    public func getDictionaryStats() -> (wordCount: Int, maxLength: Int, isLoaded: Bool) {
        return (dictionaryWords.count, maxWordLength, isLoaded)
    }
    
    public func clearCache() {
        tokenizationCache.removeAll()
    }
}

extension Tokenizer {
    
    static let shared = Tokenizer()
    // Shan language specific characters and patterns
    static let shanVowels: Set = ["ႃ", "ၢ", "ႄ", "ႅ", "ေ", "ဵ", "ိ", "ီ", "ု", "ူ", "ႆ", "ႂ", "်", "ွ", "ျ", "ြ"]
    static let shanConsonants: Set = ["ၵ", "ၷ", "ၶ", "ꧠ", "င", "ၸ", "ၹ", "သ", "ၺ", "တ", "ၻ", "ထ", "ၼ", "ꧣ", "ပ", "ၽ", "ၾ", "ပ", "ၿ", "ႀ", "မ", "ယ", "ရ", "႟", "လ", "ꩮ", "ဝ", "ႁ", "ဢ"]
    static let shanToneMarks: Set = ["ႇ", "ႈ", "း", "ႉ", "ႊ"]
    
    // Specialized method for keyboard autocomplete - focuses on the last token
    public func getLastToken(from text: String) -> String? {
        guard !text.isEmpty else { return nil }
        
        // For keyboard, we usually only care about the last 50-100 characters
        let workingText = text.count > 100 ? String(text.suffix(100)) : text
        let tokens = tokenize(workingText)
        
        return tokens.last
    }
    
    // Get potential word completions (useful for autocomplete)
    public func findWordsStartingWith(_ prefix: String, limit: Int = 10) -> [String] {
        guard !prefix.isEmpty else { return [] }
        
        return Array(dictionaryWords.filter { $0.hasPrefix(prefix) }.prefix(limit))
    }
}
