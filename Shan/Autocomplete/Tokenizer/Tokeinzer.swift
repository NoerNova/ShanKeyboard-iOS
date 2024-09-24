//
//  Tokeinzer.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 24/9/2567 BE.
//

import Foundation

public class Tokenizer {
    
    init() {
        if let path = Bundle.main.path(forResource: "dictionary", ofType: "txt"),
           let content = try? String(contentsOfFile: path) {
            dictionaryWords = Set(content.components(separatedBy: .newlines))
        }
    }
    
    private var dictionaryWords: Set<String> = []
    
    // This is the tokenize function that can be used globally
    public func tokenize(_ text: String) -> [String] {
        var words: [String] = []
        var remainingText = text
        while !remainingText.isEmpty {
            if let word = findLongestMatch(in: remainingText) {
                words.append(word)
                remainingText = String(remainingText.dropFirst(word.count))
            } else {
                words.append(String(remainingText.prefix(1)))
                remainingText = String(remainingText.dropFirst())
            }
        }
        return words
    }
    
    // Helper method to find the longest match in the dictionary
    private func findLongestMatch(in text: String) -> String? {
        for endIndex in (1...text.count).reversed() {
            let substring = String(text.prefix(endIndex))
            if dictionaryWords.contains(substring) {
                return substring
            }
        }
        return nil
    }
}
