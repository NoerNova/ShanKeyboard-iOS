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
    
    // MARK: - Dictionary Conversion Tools
    
    // Call this once to convert your text dictionary to binary format
    public static func convertTextToBinary() {
        guard let textPath = Bundle.main.path(forResource: "dictionary", ofType: "txt") else {
            print("Text dictionary not found")
            return
        }
        
        do {
            let content = try String(contentsOfFile: textPath)
            let words = content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .sorted() // Sort for potential future optimizations
            
            // Create binary format
            var binaryData = Data()
            
            // Header: word count (4 bytes) + max length (4 bytes)
            let wordCount = UInt32(words.count).bigEndian
            let maxLength = UInt32(words.max(by: { $0.count < $1.count })?.count ?? 0).bigEndian
            
            withUnsafeBytes(of: wordCount) { binaryData.append(contentsOf: $0) }
            withUnsafeBytes(of: maxLength) { binaryData.append(contentsOf: $0) }
            
            // Words: length (2 bytes) + UTF-8 data
            for word in words {
                let wordData = word.data(using: .utf8) ?? Data()
                let length = UInt16(wordData.count).bigEndian
                withUnsafeBytes(of: length) { binaryData.append(contentsOf: $0) }
                binaryData.append(wordData)
            }
            
            // Save binary dictionary
            if let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                          in: .userDomainMask).first {
                let binaryPath = documentsPath.appendingPathComponent("dictionary.bin")
                try binaryData.write(to: binaryPath)
                print("Binary dictionary saved: \(binaryData.count) bytes (was ~899KB)")
            }
            
        } catch {
            print("Error converting dictionary: \(error)")
        }
    }
    
    // MARK: - Binary Dictionary Loading
    
    init() {
        loadBinaryDictionary()
    }
    
    private func loadBinaryDictionary() {
        // Try binary format first, fallback to text
        if !loadFromBinary() {
            loadFromText()
        }
    }
    
    private func loadFromBinary() -> Bool {
        guard let path = Bundle.main.path(forResource: "dictionary", ofType: "bin"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return false
        }
        
        var offset = 0
        
        // Read header
        guard data.count >= 8 else { return false }
        
        let wordCount = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4
        
        let maxLength = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4
        
        maxWordLength = Int(maxLength)
        
        // Read words
        var words: [String] = []
        words.reserveCapacity(Int(wordCount))
        
        for _ in 0..<wordCount {
            guard offset + 2 <= data.count else { break }
            
            let length = data.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: UInt16.self).bigEndian
            }
            offset += 2
            
            guard offset + Int(length) <= data.count else { break }
            
            let wordData = data.subdata(in: offset..<offset + Int(length))
            if let word = String(data: wordData, encoding: .utf8) {
                words.append(word)
            }
            offset += Int(length)
        }
        
        dictionaryWords = Set(words)
        isLoaded = true
        
        print("Binary dictionary loaded: \(words.count) words, max length: \(maxWordLength)")
        return true
    }
    
    private func loadFromText() {
        guard let path = Bundle.main.path(forResource: "dictionary", ofType: "txt"),
              let content = try? String(contentsOfFile: path) else {
            print("Text dictionary not found")
            return
        }
        
        let words = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        dictionaryWords = Set(words)
        maxWordLength = words.max(by: { $0.count < $1.count })?.count ?? 0
        isLoaded = true
        
        print("Text dictionary loaded: \(words.count) words")
    }
    
    // MARK: - Tokenization (same as before)
    
    public func tokenize(_ text: String) -> [String] {
        guard isLoaded && !text.isEmpty else { return [] }
        
        var words: [String] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            if let (word, nextIndex) = findLongestMatch(in: text, from: currentIndex) {
                words.append(word)
                currentIndex = nextIndex
            } else {
                let nextIndex = text.index(after: currentIndex)
                words.append(String(text[currentIndex..<nextIndex]))
                currentIndex = nextIndex
            }
        }
        
        return words
    }
    
    private func findLongestMatch(in text: String, from startIndex: String.Index) -> (String, String.Index)? {
        let remainingDistance = text.distance(from: startIndex, to: text.endIndex)
        let maxCheckLength = min(maxWordLength, remainingDistance)
        
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
}
