//
//  ActionHandler.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 20/9/2567 BE.
//

import KeyboardKit
import UIKit

class ActionHandlerProvider: KeyboardAction.StandardActionHandler {

    private static let sentenceBoundaryCharacters: Set<String> = ["။", "၊", ".", ","]

    /// One-shot undo for the last accepted suggestion
    private var pendingSuggestionUndo: (insertedScalars: Int, replacedText: String)?

    /// Native iOS switches to word deletion around 2–2.5s of holding.
    private var backspacePressStart: Date?
    private static let backspaceTokenDeleteDelay: TimeInterval = 2.25

    override func handle(
        _ suggestion: Autocomplete.Suggestion
    ) {
        tryAutolearnSuggestion(suggestion)

        // Advance context window for n-gram scoring
        if let provider = autocompleteService as? AutocompleteServiceProvider {
            provider.userDidSelectSuggestion(suggestion)
        }

        // Get current input text to provide context for the suggestion
        let currentInput = keyboardContext.textDocumentProxy.customCurrentWord ?? ""

        // .unknown suggestions also come from
        // ContextualSuggestionService and CharacterPredictionService
        let undo = keyboardContext.customInsertAutocompleteSuggestion(suggestion, inputText: currentInput)
        handle(.release, on: .character(""))
        // Set AFTER the synthetic gesture above, which clears stale undo state.
        pendingSuggestionUndo = undo
    }

    override func handle(
        _ gesture: Keyboard.Gesture,
        on action: KeyboardAction
    ) {
        // Backspace acts on .press (so it can repeat); intercept before super deletes.
        if gesture == .press, action == .backspace, let undo = pendingSuggestionUndo {
            pendingSuggestionUndo = nil
            let proxy = keyboardContext.textDocumentProxy
            proxy.deleteBackward(times: undo.insertedScalars)
            if !undo.replacedText.isEmpty { proxy.insertText(undo.replacedText) }
            return
        }
        if gesture == .press { pendingSuggestionUndo = nil }

        if action == .backspace {
            switch gesture {
            case .press:
                backspacePressStart = Date()
            case .release, .end:
                backspacePressStart = nil
            case .repeatPress:
                if let start = backspacePressStart,
                   Date().timeIntervalSince(start) >= Self.backspaceTokenDeleteDelay {
                    let proxy = keyboardContext.textDocumentProxy
                    let text = proxy.documentContextBeforeInput ?? ""
                    if let token = Tokenizer.shared.getLastToken(from: text), !token.isEmpty {
                        proxy.deleteBackward(times: token.unicodeScalars.count)
                        return  // replaces this tick's single-character delete
                    }
                }
            default:
                break
            }
        }

        super.handle(gesture, on: action)

        // Reset context window at sentence boundaries
        if gesture == .release, case .character(let char) = action,
           Self.sentenceBoundaryCharacters.contains(char) {
            if let provider = autocompleteService as? AutocompleteServiceProvider {
                provider.userDidCompleteSentence()
            }
        }
    }
    
    override func tryApplyAutocorrectSuggestion(
        before gesture: Keyboard.Gesture,
        on action: KeyboardAction
    ) {
        // Highlight-only autocorrect by design: the .autocorrect tag drives the
        // toolbar highlight, but space/punctuation never auto-replaces the word.
        // The user must tap the suggestion.
    }
}

/// What a suggestion insertion changed, so a following backspace can undo it.
typealias SuggestionUndo = (insertedScalars: Int, replacedText: String)

private extension KeyboardContext {

    @discardableResult
    func customInsertAutocompleteSuggestion(
        _ suggestion: Autocomplete.Suggestion,
        inputText: String = "",
        tryInsertSpace: Bool = false
    ) -> SuggestionUndo {
        #if os(iOS) || os(tvOS) || os(visionOS)
        return textDocumentProxy.customInsertAutocompleteSuggestion(
            suggestion,
            inputText: inputText,
            tryInsertSpace: tryInsertSpace)
        #else
        return (0, "")
        #endif
    }
}

private extension UITextDocumentProxy {
    
    var customCurrentWord: String? {
        let pre = currentWordPreCursorPart
        let post = currentWordPostCursorPart
        if pre == nil && post == nil { return nil }

        let prePost = (pre ?? "") + (post ?? "")

        /// Use LanguageService.getCurrentWord instead of Tokenizer to avoid
        /// splitting combining characters like "ၢ" into separate tokens.
        let word = SharedResources.shared.shanLanguageService.getCurrentWord(from: prePost)
        return word.isEmpty ? prePost : word
    }
    
    @discardableResult
    func customInsertAutocompleteSuggestion(
        _ suggestion: Autocomplete.Suggestion,
        inputText: String,
        tryInsertSpace: Bool = true
    ) -> SuggestionUndo {
        let undo = insertProcessedSuggestion(suggestion.text, inputText: inputText)
        if tryInsertSpace { tryInsertSpaceAfterAutocomplete() }
        return undo
    }

    private func insertProcessedSuggestion(_ suggestionText: String, inputText: String) -> SuggestionUndo {
        // A suggestion identical to the current word is a reduplication tap
        // (မႂ်ႇ → မႂ်ႇမႂ်ႇ is normal Shan). The replace path would delete and
        // re-insert the same scalars — a no-op the user reads as a dead button —
        // so append a second copy instead.
        if !inputText.isEmpty, suggestionText.unicodeScalars.elementsEqual(inputText.unicodeScalars) {
            insertText(suggestionText)
            return (suggestionText.unicodeScalars.count, "")
        }

        // Determine if this is a completion suffix or a full word replacement
        if isCompletionSuffix(suggestionText, for: inputText) {
            // Just append the completion part
            insertText(suggestionText)
            return (suggestionText.unicodeScalars.count, "")
        } else {
            // Replace the entire current word
            return customReplaceCurrentWordPreCursorPart(with: suggestionText)
        }
    }
    
    private func isCompletionSuffix(_ suggestionText: String, for inputText: String) -> Bool {
        guard !inputText.isEmpty else { return false }

        // Must use Unicode scalar comparison — Shan combining chars like "ၢ"
        // cause grapheme-level hasPrefix/contains to fail.
        // e.g. "ၺၢၼ်ႇ".hasPrefix("ၺၢၼ") is FALSE at grapheme level
        // because grapheme "ၼ" ≠ "ၼ်", but at scalar level it's a valid prefix.

        // If suggestion starts with input (scalar-level), it's a full word replacement
        if suggestionText.unicodeScalars.starts(with: inputText.unicodeScalars) {
            return false
        }

        if let currentWord = customCurrentWord {
            // Check scalar-level prefix
            if suggestionText.unicodeScalars.starts(with: currentWord.unicodeScalars) {
                return false
            }
            // Check scalar-level containment
            let sScalars = Array(suggestionText.unicodeScalars)
            let wScalars = Array(currentWord.unicodeScalars)
            if wScalars.count <= sScalars.count {
                for i in 0...(sScalars.count - wScalars.count) {
                    if Array(sScalars[i..<(i + wScalars.count)]) == wScalars {
                        return false
                    }
                }
            }
            return true
        }

        return false
    }
    
    @discardableResult
    func customReplaceCurrentWordPreCursorPart(with replacement: String) -> SuggestionUndo {
        let preCursor = currentWordPreCursorPart ?? ""
        let preScalars = Array(preCursor.unicodeScalars)
        let repScalars = Array(replacement.unicodeScalars)

        // Find the longest suffix of the pre-cursor text that matches
        // a prefix of the replacement. This handles multi-syllable Shan words
        // where extractLastIncompleteWord only returns the last syllable,
        // but the suggestion contains the full word (e.g. typed "မၢၵ်ႇၽ",
        // suggestion "မၢၵ်ႇၽႃႈ" — overlap is all 6 scalars, not just "ၽ").
        let maxCheck = min(preScalars.count, repScalars.count)
        var overlapLength = 0
        for len in stride(from: maxCheck, through: 1, by: -1) {
            if Array(preScalars.suffix(len)) == Array(repScalars.prefix(len)) {
                overlapLength = len
                break
            }
        }

        var replaced = ""
        if overlapLength > 0 {
            deleteBackward(times: overlapLength)
            replaced = String(String.UnicodeScalarView(preScalars.suffix(overlapLength)))
        } else if let text = customCurrentWord {
            deleteBackward(times: text.unicodeScalars.count)
            replaced = text
        }
        insertText(replacement)
        return (repScalars.count, replaced)
    }
}
