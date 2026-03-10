//
//  LanguageService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 20/7/2568 BE.
//

import Foundation

class ShanLanguageService {

    // Use shared dictionary service via singleton - no more per-instance creation
    private var dictionaryService: DictionaryService {
        SharedResources.shared.dictionaryService
    }

    // MARK: - Shan Language Character Sets (delegating to ShanGrammarRules)
    var shanVowels: Set<String> { ShanGrammarRules.vowels }
    var shanConsonants: Set<String> { ShanGrammarRules.consonants }
    var shanToneMarks: Set<String> { ShanGrammarRules.toneMarks }
    var shanMedials: Set<String> { ShanGrammarRules.medials }
    var finalConsonants: Set<String> { ShanGrammarRules.finalConsonants }

    // MARK: - Common Shan Words for Fallback
    let commonShanWords = ["ယဝ်ႉ", "ၶႃႈ", "ဢေႃႈ", "ၵဝ်", "ၶဝ်", "သူ", "ႁဝ်း", "ႁႃး", "ၸဝ်ႈ", "မႂ်ႇသုင်"]

    // MARK: - Word Boundary Markers
    let wordBoundaryCharacters = CharacterSet(charactersIn: " ။၊\n\t")

    // Regex-based syllable pattern inspired by ShanNLP's syllable_break.py
    // Matches: consonant + optional medial + vowel + optional final consonant + optional tone mark
    private static let syllablePattern: NSRegularExpression? = {
        // Shan syllable structure: C (medial)? V (Cf)? (T)?
        // Using Unicode ranges for Shan characters
        let pattern = "[\u{1000}-\u{109F}\u{AA60}-\u{AA7F}][\u{103B}-\u{103E}\u{1082}]?[\u{102B}-\u{1039}\u{103A}\u{1056}-\u{1059}\u{105E}-\u{1060}\u{1062}-\u{1064}\u{1067}-\u{106D}\u{1071}-\u{1074}\u{1083}-\u{108D}\u{109A}-\u{109D}\u{AA7B}-\u{AA7D}]*"
        return try? NSRegularExpression(pattern: pattern)
    }()

    // MARK: - Syllable Extraction
    func extractSyllables(from text: String) -> [String] {
        // Try regex-based extraction first
        if let pattern = ShanLanguageService.syllablePattern {
            let nsText = text as NSString
            let range = NSRange(location: 0, length: nsText.length)
            let matches = pattern.matches(in: text, range: range)

            if !matches.isEmpty {
                let syllables = matches.map { nsText.substring(with: $0.range) }
                if !syllables.isEmpty {
                    return syllables
                }
            }
        }

        // Fallback: rule-based syllable boundary detection
        return extractSyllablesRuleBased(from: text)
    }

    private func extractSyllablesRuleBased(from text: String) -> [String] {
        var syllables: [String] = []
        var currentSyllable = ""
        let chars = Array(text)

        for (index, char) in chars.enumerated() {
            let charStr = String(char)
            currentSyllable += charStr

            if shanVowels.contains(charStr) || shanToneMarks.contains(charStr) {
                let nextIndex = index + 1
                if nextIndex < chars.count {
                    let nextChar = String(chars[nextIndex])
                    if shanConsonants.contains(nextChar) && !shanToneMarks.contains(nextChar) {
                        syllables.append(currentSyllable)
                        currentSyllable = ""
                    }
                } else {
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
    func getLastCompleteWord(from text: String) -> String? {
        let tokens = Tokenizer.shared.tokenize(text)
        guard !tokens.isEmpty else { return nil }

        if let last = tokens.last, dictionaryService.isValidWord(last) { return last }

        if tokens.count >= 2 {
            let prev = tokens[tokens.count - 2]
            return dictionaryService.isValidWord(prev) ? prev : nil
        }
        return nil
    }

    func getCurrentIncompleteWord(from text: String) -> String {
        if let last = Tokenizer.shared.getLastToken(from: text) {
            return dictionaryService.isValidWord(last) ? "" : last
        }
        let components = text.components(separatedBy: wordBoundaryCharacters)
        return components.last?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    func lastValidToken(in text: String) -> String? {
        let tokens = Tokenizer.shared.tokenize(text)
        return tokens.reversed().first { dictionaryService.isValidWord($0) }
    }

    func lastInvalidToken(in text: String) -> String? {
        let tokens = Tokenizer.shared.tokenize(text)
        guard let last = tokens.last else { return nil }
        return dictionaryService.isValidWord(last) ? nil : last
    }

    func parseWords(from text: String) -> [String] {
        return text.components(separatedBy: wordBoundaryCharacters)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Character Pattern Analysis
    func getCommonContinuations(for lastCharacter: String) -> [String] {
        if shanConsonants.contains(lastCharacter) {
            var continuations = ["ိ", "ီ", "ု", "ူ", "ေ"]
            // Only offer medials that form valid clusters
            for medial in shanMedials {
                if ShanGrammarRules.isValidCluster(consonant: lastCharacter, medial: medial) {
                    continuations.append(medial)
                }
            }
            return continuations
        } else if shanVowels.contains(lastCharacter) {
            return Array(finalConsonants)
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
               shanToneMarks.contains(character) ||
               shanMedials.contains(character) ||
               character == ShanGrammarRules.asat
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
        if text.isEmpty || text.count < 2 { return false }

        let onlyVowels = text.unicodeScalars.allSatisfy { shanVowels.contains(String($0)) }
        if onlyVowels { return false }

        return dictionaryService.isValidWord(text)
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
