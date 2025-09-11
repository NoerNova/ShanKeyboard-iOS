//
//  LanguageService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 20/7/2568 BE.
//

import Foundation

class ShanLanguageService {
    
    // MARK: - Shan Language Character Sets
    let shanVowels: Set<String> = ["ႃ", "ၢ", "ႄ", "ႅ", "ေ", "ဵ", "ိ", "ီ", "ု", "ူ", "ႆ", "ႂ", "်", "ွ", "ျ", "ြ"]
    let shanConsonants: Set<String> = ["ၵ", "ၷ", "ၶ", "ꧠ", "င", "ၸ", "ၹ", "သ", "ၺ", "တ", "ၻ", "ထ", "ၼ", "ꧣ", "ပ", "ၽ", "ၾ", "ပ", "ၿ", "ႀ", "မ", "ယ", "ရ", "႟", "လ", "ꩮ", "ဝ", "ႁ", "ဢ"]
    let shanToneMarks: Set<String> = ["ႇ", "ႈ", "း", "ႉ", "ႊ"]
    
    // MARK: - Common Shan Words for Fallback
    // TODO: Should analyze/research for Shan's common word
    let commonShanWords = ["ၸၢင်ႈ", "မိူင်း", "ၵုင်း", "ပွၼ်", "လွင်ႈ", "ထၢမ်", "ၸိုင်ႈ", "ပီ", "ႁူဝ်", "ၸႂ်"]
    
    // MARK: - Word Boundary Markers
    let wordBoundaryCharacters = CharacterSet(charactersIn: " ။၊\n\t")
    
    // MARK: - Syllable Extraction
    func extractSyllables(from text: String) -> [String] {
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
    
    func extractCurrentSyllable(from text: String) -> String {
        let syllables = extractSyllables(from: text)
        return syllables.last ?? text
    }
    
    // MARK: - Word Parsing
    // TODO: Shan language do not have such a word boundary characters
    // TODO: Should use tokenize instead
    func getLastCompleteWord(from text: String) -> String? {
//        let components = text.components(separatedBy: wordBoundaryCharacters)
        let components = Tokenizer.shared.tokenize(text)
        let filtered = components.filter { !$0.isEmpty }
        return filtered.count >= 2 ? filtered[filtered.count - 2] : nil
    }
    
    func getCurrentIncompleteWord(from text: String) -> String {
        // Prefer tokenizer: take the last token or partial sequence near the end
        if let last = Tokenizer.shared.getLastToken(from: text) {
            return last
        }
        // Fallback to simple boundary split
        let components = text.components(separatedBy: wordBoundaryCharacters)
        return components.last?.trimmingCharacters(in: .whitespaces) ?? ""
    }
    
    func parseWords(from text: String) -> [String] {
        return text.components(separatedBy: wordBoundaryCharacters)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    // MARK: - Character Pattern Analysis
    func getCommonContinuations(for lastCharacter: String) -> [String] {
        if shanConsonants.contains(lastCharacter) {
            return ["ိ", "ီ", "ု", "ူ", "ေ", "ျ", "ြ"]
        } else if shanVowels.contains(lastCharacter) {
            return ["ႇ", "ႈ", "း", "ၵ", "တ", "ပ"]
        }
        return []
    }
    
    func getCommonExtensions() -> [String] {
        return ["း", "ႈ", "ႇ", "ိ", "ီ", "ု", "ူ"]
    }
    
    // MARK: - Language Validation
    func isValidShanCharacter(_ character: String) -> Bool {
        return shanVowels.contains(character) ||
               shanConsonants.contains(character) ||
               shanToneMarks.contains(character)
    }
    
    func isConsonant(_ character: String) -> Bool {
        return shanConsonants.contains(character)
    }
    
    func isVowel(_ character: String) -> Bool {
        return shanVowels.contains(character)
    }
    
    func isToneMark(_ character: String) -> Bool {
        return shanToneMarks.contains(character)
    }
    
    // MARK: - Syllable Structure Analysis
    func analyzeSyllableStructure(_ syllable: String) -> SyllableStructure {
        let chars = Array(syllable).map(String.init)
        var structure = SyllableStructure()
        
        for char in chars {
            if shanConsonants.contains(char) {
                if structure.initialConsonant == nil {
                    structure.initialConsonant = char
                } else {
                    structure.finalConsonant = char
                }
            } else if shanVowels.contains(char) {
                structure.vowel = char
            } else if shanToneMarks.contains(char) {
                structure.toneMark = char
            }
        }
        
        return structure
    }
    
    func isValidShanWord(_ text: String) -> Bool {
        if text.isEmpty || text.count < 2 {
            return false
        }
        
        let onlyVowels = text.unicodeScalars.allSatisfy { shanVowels.contains(String($0)) }
        if onlyVowels {
            return false
        }
        
        // Final chck: must be in dictionary
        return DictionaryService().isValidWord(text)
    }
}

// MARK: - Supporting Structures
struct SyllableStructure {
    var initialConsonant: String?
    var vowel: String?
    var finalConsonant: String?
    var toneMark: String?
    
    var isComplete: Bool {
        return initialConsonant != nil && vowel != nil
    }
}
