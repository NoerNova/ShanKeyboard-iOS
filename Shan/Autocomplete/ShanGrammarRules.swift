//
//  ShanGrammarRules.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 10/3/2569 BE.
//

import Foundation

struct ShanGrammarRules {

    // MARK: - Character Sets

    static let consonants: Set<String> = [
        "ၵ", "ၷ", "ၶ", "ꧠ", "င", "ၸ", "ၹ", "သ", "ၺ",
        "တ", "ၻ", "ထ", "ၼ", "ꧣ", "ပ", "ၽ", "ၾ", "ၿ",
        "ႀ", "မ", "ယ", "ရ", "႟", "လ", "ꩮ", "ဝ", "ႁ", "ဢ"
    ]

    static let vowels: Set<String> = [
        "ႃ", "ၢ", "ႄ", "ႅ", "ေ", "ဵ", "ိ", "ီ", "ု", "ူ", "ႆ", "ႂ", "ွ"
    ]

    static let medials: Set<String> = ["ျ", "ြ"]

    static let toneMarks: Set<String> = ["ႇ", "ႈ", "း", "ႉ", "ႊ"]

    static let asat: String = "်"

    static let finalConsonantBases: Set<String> = ["ၵ", "င", "တ", "ၼ", "ၺ", "ပ", "မ", "ဝ"]

    /// Pre-computed final consonants: base + ်
    static let finalConsonants: Set<String> = {
        Set(finalConsonantBases.map { $0 + asat })
    }()

    // MARK: - Rule 1: Valid Consonant Clusters

    static let validHorpClusters: Set<String> = ["ၵျ", "ၶျ", "ပျ", "မျ"]
    static let validLapeClusters: Set<String> = ["ၵြ", "ၶြ", "တြ", "ပြ", "ၽြ", "မြ", "သြ"]

    static func isValidCluster(consonant: String, medial: String) -> Bool {
        let cluster = consonant + medial
        if medial == "ျ" { return validHorpClusters.contains(cluster) }
        if medial == "ြ" { return validLapeClusters.contains(cluster) }
        return false
    }

    // MARK: - Unicode Scalar Helpers

    /// Split text into individual Unicode scalars as strings.
    /// Unlike `Array(text)` which groups combining characters into grapheme clusters,
    /// this preserves each scalar separately (e.g. "မၢ" → ["မ","ၢ"] not ["မၢ"]).
    static func scalarChars(_ text: String) -> [String] {
        text.unicodeScalars.map { String($0) }
    }

    static func scalarCount(_ text: String) -> Int {
        text.unicodeScalars.count
    }

    static func lastScalar(_ text: String) -> String? {
        text.unicodeScalars.last.map { String($0) }
    }

    static func firstScalar(_ text: String) -> String? {
        text.unicodeScalars.first.map { String($0) }
    }

    // MARK: - Character Type Classification

    enum CharType: Hashable {
        case consonant
        case vowel
        case medial
        case toneMark
        case asat
        case finalConsonant
        case specialVowelHoy   // ွ
        case specialVowelGuaiTai   // ႂ
        case kaikhuen       // ႆ
        case unknown
    }

    static func charType(of char: String) -> CharType {
        if toneMarks.contains(char) { return .toneMark }
        if char == asat { return .asat }
        if char == "ႆ" { return .kaikhuen }
        if char == "ွ" { return .specialVowelHoy }
        if char == "ႂ" { return .specialVowelGuaiTai }
        if medials.contains(char) { return .medial }
        if consonants.contains(char) { return .consonant }
        if vowels.contains(char) { return .vowel }
        return .unknown
    }

    // MARK: - Rule: canFollow (pair-level validation)

    /// Returns whether `next` can follow `current` in a valid Shan sequence.
    static func canFollow(current: String, next: String) -> Bool {
        let curType = charType(of: current)
        let nextType = charType(of: next)

        switch curType {
        case .consonant:
            // After consonant: vowel, medial (if valid cluster), asat (if valid final base), another consonant (new word), special vowels
            switch nextType {
            case .consonant: return true  // new word start
            case .vowel, .specialVowelHoy, .specialVowelGuaiTai, .kaikhuen: return true
            case .medial: return isValidCluster(consonant: current, medial: next)
            case .asat: return finalConsonantBases.contains(current)
            case .toneMark: return false  // consonant alone can't take tone mark
            case .unknown: return true
            case .finalConsonant: return false
            }

        case .medial:
            // After medial: vowel, special vowels
            switch nextType {
            case .vowel, .specialVowelHoy, .specialVowelGuaiTai, .kaikhuen: return true
            case .consonant: return true  // rare but possible new word
            default: return false
            }

        case .vowel:
            // After ၢ: expect only finalConsonantBases (consonant) or ႆ, no tone marks
            if current == "ၢ" {
                switch nextType {
                case .consonant: return finalConsonantBases.contains(next)
                case .kaikhuen: return true
                default: return false
                }
            }
            // Allow compound vowels: ိ+ု, ိ+ူ, ေ+ႃ
            if current == "ိ" && (next == "ု" || next == "ူ") {
                return true
            }
            if current == "ေ" && next == "ႃ" {
                return true
            }
            // After vowel: tone mark, final consonant (via consonant+asat), another consonant (new word)
            switch nextType {
            case .toneMark: return true
            case .consonant: return true  // could be final consonant base or new word
            case .asat: return false      // asat needs a consonant before it
            case .vowel: return false     // no consecutive vowels
            case .medial: return false
            case .specialVowelHoy, .specialVowelGuaiTai, .kaikhuen: return false
            case .unknown: return true
            case .finalConsonant: return false
            }

        case .specialVowelHoy:
            // Rule 4: After ွ → expect ႆ or final consonant (consonant that forms final)
            switch nextType {
            case .kaikhuen: return true
            case .consonant: return true  // final consonant base or new word
            case .toneMark: return true
            case .asat: return false
            default: return false
            }

        case .specialVowelGuaiTai:
            // Rule 5: After ႂ → expect vowel (ႂ acts as medial), ႆ, final consonant, or tone mark
            switch nextType {
            case .vowel: return true
            case .kaikhuen: return true
            case .consonant: return true
            case .toneMark: return true
            case .asat: return false
            default: return false
            }

        case .kaikhuen:
            // After ႆ: tone mark or new consonant
            switch nextType {
            case .toneMark: return true
            case .consonant: return true
            default: return false
            }

        case .toneMark:
            // Rule 6: No consecutive tone marks. After tone mark → new word (consonant) only
            switch nextType {
            case .consonant: return true
            case .toneMark: return false
            default: return false
            }

        case .asat:
            // Rule 3: After final consonant (consonant+်) → tone mark or new word (consonant)
            switch nextType {
            case .toneMark: return true
            case .consonant: return true
            default: return false
            }

        case .finalConsonant:
            // Should not appear as a single char type, but handle similarly to asat
            switch nextType {
            case .toneMark: return true
            case .consonant: return true
            default: return false
            }

        case .unknown:
            return true
        }
    }

    // MARK: - String-level validation

    /// Walks the string checking all adjacent character pairs.
    static func isGrammaticallyValid(_ text: String) -> Bool {
        let chars = scalarChars(text)
        guard chars.count > 1 else { return true }

        for i in 1..<chars.count {
            if !canFollow(current: chars[i - 1], next: chars[i]) {
                return false
            }
        }
        return true
    }

    // MARK: - Word Boundary Detection

    /// Scans backward through continuous Shan text to find the last word boundary,
    /// returning only the current incomplete word (for trie prefix lookup).
    static func extractLastIncompleteWord(from text: String) -> String {
        let scalars = scalarChars(text)
        guard scalars.count > 1 else { return text }

        let maxScan = min(scalars.count, 50)
        let startIdx = scalars.count - maxScan

        for i in stride(from: scalars.count - 1, through: startIdx + 1, by: -1) {
            let curr = scalars[i]
            let currType = charType(of: curr)
            guard currType == .consonant else { continue }  // words start with consonants

            let prev = scalars[i - 1]
            let prevType = charType(of: prev)

            switch prevType {
            case .toneMark, .asat, .kaikhuen:
                // DEFINITE boundary: these end a syllable
                return scalars[i...].joined()

            case .vowel, .specialVowelHoy, .specialVowelGuaiTai:
                // AMBIGUOUS: consonant after vowel could be final or new word
                if i + 1 < scalars.count {
                    let nextType = charType(of: scalars[i + 1])
                    if nextType == .asat {
                        continue  // final consonant (same word), keep scanning
                    }
                    // Followed by vowel/medial/consonant → new word
                    return scalars[i...].joined()
                } else {
                    // Last character being typed
                    if finalConsonantBases.contains(curr) {
                        continue  // likely final consonant needing asat, same word
                    }
                    return scalars[i...].joined()
                }

            default:
                continue
            }
        }

        // No boundary found — return capped segment
        return scalars[startIdx...].joined()
    }

    // MARK: - Prediction hints

    /// Returns the set of CharTypes that can follow the last character of the given text.
    static func expectedNext(after text: String) -> Set<CharType> {
        guard let lastChar = lastScalar(text) else {
            return [.consonant]  // word start
        }

        let chars = scalarChars(text)
        let count = chars.count
        let curType = charType(of: lastChar)

        switch curType {
        case .consonant:
            var expected: Set<CharType> = [.vowel, .specialVowelHoy, .specialVowelGuaiTai, .kaikhuen, .consonant]
            // Check if this consonant can take medials
            if validHorpClusters.contains(where: { $0.hasPrefix(lastChar) }) ||
               validLapeClusters.contains(where: { $0.hasPrefix(lastChar) }) {
                expected.insert(.medial)
            }
            // Check if this consonant can take asat
            if finalConsonantBases.contains(lastChar) {
                expected.insert(.asat)
            }
            return expected

        case .medial:
            return [.vowel, .specialVowelHoy, .specialVowelGuaiTai, .kaikhuen, .consonant]

        case .vowel:
            // After ိ+ု or ိ+ူ: expect only finalConsonantBases (consonant) to form final with asat
            if count >= 2 {
                let secondLast = chars[count - 2]
                if secondLast == "ိ" && (lastChar == "ု" || lastChar == "ူ") {
                    return [.consonant]  // only finalConsonantBases, asat follows after
                }
            }
            // After ိ: allow compound vowels ို and ိူ
            if lastChar == "ိ" {
                return [.vowel, .toneMark, .consonant]
            }
            // After ေ: allow compound vowel ေႃ
            if lastChar == "ေ" {
                return [.vowel, .toneMark, .consonant]
            }
            // After ၢ: expect finalConsonantBases+asat or ႆ
            if lastChar == "ၢ" {
                return [.consonant, .kaikhuen]
            }
            return [.toneMark, .consonant]

        case .specialVowelHoy:
            return [.kaikhuen, .consonant, .toneMark]

        case .specialVowelGuaiTai:
            return [.vowel, .kaikhuen, .consonant, .toneMark]

        case .kaikhuen:
            return [.toneMark, .consonant]

        case .toneMark:
            return [.consonant]

        case .asat:
            // After ၵ်, တ်, ပ်: expect tone mark only
            if count >= 2 {
                let consonantBefore = chars[count - 2]
                if consonantBefore == "ၵ" || consonantBefore == "တ" || consonantBefore == "ပ" {
                    return [.toneMark]
                }
            }
            return [.toneMark, .consonant]

        case .finalConsonant:
            return [.toneMark, .consonant]

        case .unknown:
            return [.consonant]
        }
    }
}
