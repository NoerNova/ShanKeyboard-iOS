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
            // Rule 5: After ႂ → expect ႆ or final consonant
            switch nextType {
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
        let chars = Array(text).map(String.init)
        guard chars.count > 1 else { return true }

        for i in 1..<chars.count {
            if !canFollow(current: chars[i - 1], next: chars[i]) {
                return false
            }
        }
        return true
    }

    // MARK: - Prediction hints

    /// Returns the set of CharTypes that can follow the last character of the given text.
    static func expectedNext(after text: String) -> Set<CharType> {
        guard let lastChar = text.last.map(String.init) else {
            return [.consonant]  // word start
        }

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
            return [.toneMark, .consonant]

        case .specialVowelHoy, .specialVowelGuaiTai:
            return [.kaikhuen, .consonant, .toneMark]

        case .kaikhuen:
            return [.toneMark, .consonant]

        case .toneMark:
            return [.consonant]

        case .asat:
            return [.toneMark, .consonant]

        case .finalConsonant:
            return [.toneMark, .consonant]

        case .unknown:
            return [.consonant]
        }
    }
}
