//
//  DictionaryService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 17/7/2568 BE.
//

import Foundation
import KeyboardKit

class DictionaryService {
    private var trie = TrieNode()
    private var syllableTrie = TrieNode()
    private let cacheSize = 1000
    private var searchCache = NSCache<NSString, NSArray>()
    
    init() {
        loadDictionary()
        searchCache.countLimit = cacheSize
    }
    
    // Integration with your existing AutocompleteServiceProvider
    func getDictionarySuggestions(for prefix: String, limit: Int = 5) -> [Autocomplete.Suggestion] {
        let matches = searchWords(prefix: prefix, limit: limit)
        return matches.map { match in
            Autocomplete.Suggestion(text: match.word, type: .regular)
        }
    }
    
    func getSyllableSuggestions(for prefix: String, limit: Int = 5) -> [Autocomplete.Suggestion] {
        let matches = searchSyllables(prefix: prefix, limit: limit)
        return matches.map { match in
            Autocomplete.Suggestion(text: match.word, type: .regular)
        }
    }
    
    private func loadDictionary() {
        // Load from JSON format for better performance
        if let path = Bundle.main.path(forResource: "filtered_frequency_data", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let dictionaryData = try? JSONDecoder().decode(DictionaryData.self, from: data) {
            
            // Build word trie
            for entry in dictionaryData.words {
                trie.insert(entry.word, frequency: entry.frequency)
            }
            
            // Build syllable trie
            for entry in dictionaryData.syllables {
                syllableTrie.insert(entry.syllable, frequency: entry.frequency)
            }
        }
    }
    
    func searchWords(prefix: String, limit: Int = 10) -> [DictionaryMatch] {
        let cacheKey = "\(prefix)_\(limit)" as NSString
        
        if let cached = searchCache.object(forKey: cacheKey) as? [DictionaryMatch] {
            return cached
        }
        
        guard let prefixNode = trie.searchPrefix(prefix) else {
            return []
        }
        
        let results = prefixNode.getAllWords(limit: limit).map {
            DictionaryMatch(word: $0.word, frequency: $0.frequency, type: .dictionary)
        }
        
        searchCache.setObject(results as NSArray, forKey: cacheKey)
        return results
    }
    
    func searchSyllables(prefix: String, limit: Int = 5) -> [DictionaryMatch] {
        guard let prefixNode = syllableTrie.searchPrefix(prefix) else {
            return []
        }
        
        return prefixNode.getAllWords(limit: limit).map {
            DictionaryMatch(word: $0.word, frequency: $0.frequency, type: .syllable)
        }
    }
}

struct DictionaryData: Codable {
    let words: [WordEntry]
    let syllables: [SyllableEntry]
}

struct WordEntry: Codable {
    let word: String
    let frequency: Int
    let category: String?
    let meaning: String?
}

struct SyllableEntry: Codable {
    let syllable: String
    let frequency: Int
}

struct DictionaryMatch {
    let word: String
    let frequency: Int
    let type: MatchType
    
    enum MatchType {
        case dictionary
        case syllable
        case learned
    }
}
