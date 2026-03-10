//
//  SpellCorrectionService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 10/3/2569 BE.
//  Adapted from ShanNLP project
//

import Foundation
import KeyboardKit

class SpellCorrectionService {

    private var dictionaryService: DictionaryService {
        SharedResources.shared.dictionaryService
    }

    private var shanLanguageService: ShanLanguageService {
        SharedResources.shared.shanLanguageService
    }

    // Shan-aware edit distance weights
    private let toneMarkSubstitutionCost: Double = 0.5
    private let vowelPositionErrorCost: Double = 0.7
    private let phoneticSimilarConsonantCost: Double = 0.6
    private let standardChangeCost: Double = 1.0

    // Phonetically similar consonant groups
    private let similarConsonantGroups: [[String]] = [
        ["ၵ", "ၶ"],        // k-group
        ["ၸ", "သ"],        // s-group
        ["တ", "ထ"],        // t-group
        ["ပ", "ၽ", "ၾ"],  // p-group
        ["ၼ", "ꧣ"],        // n-group
    ]

    private lazy var similarConsonantMap: [String: Set<String>] = {
        var map: [String: Set<String>] = [:]
        for group in similarConsonantGroups {
            for c in group {
                map[c] = Set(group.filter { $0 != c })
            }
        }
        return map
    }()

    // MARK: - Public API

    func getSuggestions(for text: String, limit: Int = 3) -> [Autocomplete.Suggestion] {
        let candidates = generateCandidates(for: text)

        // Score and sort — reject grammatically invalid candidates
        var scored: [(String, Double)] = []
        for candidate in candidates {
            guard ShanGrammarRules.isGrammaticallyValid(candidate) else { continue }
            let dist = shanEditDistance(text, candidate)
            if dist <= 1.5 {
                scored.append((candidate, dist))
            }
        }
        scored.sort { $0.1 < $1.1 }

        return scored.prefix(limit).map {
            Autocomplete.Suggestion(text: $0.0, type: .regular)
        }
    }

    // MARK: - Candidate Generation (edit distance 1)

    private func generateCandidates(for word: String) -> Set<String> {
        var candidates = Set<String>()
        let chars = Array(word).map(String.init)
        let n = chars.count

        // All valid Shan characters for insertion/replacement (corrected sets)
        let allChars = Array(ShanGrammarRules.consonants) +
                        Array(ShanGrammarRules.vowels) +
                        Array(ShanGrammarRules.medials) +
                        Array(ShanGrammarRules.toneMarks)

        // Deletions
        for i in 0..<n {
            var modified = chars
            modified.remove(at: i)
            let candidate = modified.joined()
            if dictionaryService.isValidWord(candidate) {
                candidates.insert(candidate)
            }
        }

        // Transpositions
        for i in 0..<n - 1 {
            var modified = chars
            modified.swapAt(i, i + 1)
            let candidate = modified.joined()
            if dictionaryService.isValidWord(candidate) {
                candidates.insert(candidate)
            }
        }

        // Replacements - only try phonetically similar characters for speed
        for i in 0..<n {
            let original = chars[i]
            var tryChars: [String] = []

            // Tone mark replacements
            if ShanGrammarRules.toneMarks.contains(original) {
                tryChars = Array(ShanGrammarRules.toneMarks)
            }
            // Phonetically similar consonant replacements
            else if let similar = similarConsonantMap[original] {
                tryChars = Array(similar)
            }
            // Vowel replacements (corrected set without medials)
            else if ShanGrammarRules.vowels.contains(original) {
                tryChars = Array(ShanGrammarRules.vowels)
            }
            // Medial replacements
            else if ShanGrammarRules.medials.contains(original) {
                tryChars = Array(ShanGrammarRules.medials)
            }
            // For other characters, try common ones
            else {
                tryChars = Array(allChars.prefix(15))
            }

            for replacement in tryChars where replacement != original {
                var modified = chars
                modified[i] = replacement
                let candidate = modified.joined()
                if dictionaryService.isValidWord(candidate) {
                    candidates.insert(candidate)
                }
            }
        }

        // Insertions - limited to positions that could form valid prefixes
        for i in 0...n {
            for char in allChars.prefix(20) {
                var modified = chars
                modified.insert(char, at: i)
                let candidate = modified.joined()
                if dictionaryService.isValidWord(candidate) {
                    candidates.insert(candidate)
                }
            }
        }

        return candidates
    }

    // MARK: - Shan-Aware Edit Distance

    private func shanEditDistance(_ s1: String, _ s2: String) -> Double {
        let a = Array(s1).map(String.init)
        let b = Array(s2).map(String.init)
        let m = a.count
        let n = b.count

        var dp = Array(repeating: Array(repeating: 0.0, count: n + 1), count: m + 1)

        for i in 0...m { dp[i][0] = Double(i) }
        for j in 0...n { dp[0][j] = Double(j) }

        for i in 1...m {
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    let substitutionCost = weightedSubstitutionCost(a[i - 1], b[j - 1])
                    dp[i][j] = min(
                        dp[i - 1][j] + standardChangeCost,     // deletion
                        dp[i][j - 1] + standardChangeCost,     // insertion
                        dp[i - 1][j - 1] + substitutionCost    // substitution
                    )
                }
            }
        }

        return dp[m][n]
    }

    private func weightedSubstitutionCost(_ a: String, _ b: String) -> Double {
        // Both tone marks
        if ShanGrammarRules.toneMarks.contains(a) && ShanGrammarRules.toneMarks.contains(b) {
            return toneMarkSubstitutionCost
        }

        // Phonetically similar consonants
        if let similar = similarConsonantMap[a], similar.contains(b) {
            return phoneticSimilarConsonantCost
        }

        // Both vowels (corrected set)
        if ShanGrammarRules.vowels.contains(a) && ShanGrammarRules.vowels.contains(b) {
            return vowelPositionErrorCost
        }

        return standardChangeCost
    }
}
