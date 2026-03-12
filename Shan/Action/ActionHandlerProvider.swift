//
//  ActionHandler.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 20/9/2567 BE.
//

import KeyboardKit
import UIKit

class ActionHandlerProvider: KeyboardAction.StandardActionHandler {
    
    override func handle(
        _ suggestion: Autocomplete.Suggestion
    ) {
        tryAutolearnSuggestion(suggestion)
        
        // Get current input text to provide context for the suggestion
        let currentInput = keyboardContext.textDocumentProxy.customCurrentWord ?? ""
        keyboardContext.customInsertAutocompleteSuggestion(suggestion, inputText: currentInput)
        handle(.release, on: .character(""))
    }
    
    override func tryApplyAutocorrectSuggestion(
        before gesture: Keyboard.Gesture,
        on action: KeyboardAction
    ) {
        guard shouldApplyAutocorrectSuggestion(before: gesture, on: action) else { return }
        let suggestions = autocompleteContext.suggestions
        let autocorrect = suggestions.first { $0.isAutocorrect }
        guard let suggestion = autocorrect else { return }
        
        let currentInput = keyboardContext.textDocumentProxy.customCurrentWord ?? ""
        keyboardContext.customInsertAutocompleteSuggestion(
            suggestion,
            inputText: currentInput,
            tryInsertSpace: false
        )
    }
}

private extension KeyboardContext {
    
    func customInsertAutocompleteSuggestion(
        _ suggestion: Autocomplete.Suggestion,
        inputText: String = "",
        tryInsertSpace: Bool = false
    ) {
        #if os(iOS) || os(tvOS) || os(visionOS)
        textDocumentProxy.customInsertAutocompleteSuggestion(
            suggestion,
            inputText: inputText,
            tryInsertSpace: tryInsertSpace)
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
    
    func customInsertAutocompleteSuggestion(
        _ suggestion: Autocomplete.Suggestion,
        inputText: String,
        tryInsertSpace: Bool = true
    ) {
        insertProcessedSuggestion(suggestion.text, inputText: inputText)
        guard tryInsertSpace else { return }
        tryInsertSpaceAfterAutocomplete()
    }
    
    private func insertProcessedSuggestion(_ suggestionText: String, inputText: String) {
        // Determine if this is a completion suffix or a full word replacement
        if isCompletionSuffix(suggestionText, for: inputText) {
            // Just append the completion part
            insertText(suggestionText)
        } else {
            // Replace the entire current word
            customReplaceCurrentWordPreCursorPart(with: suggestionText)
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
    
    func customReplaceCurrentWordPreCursorPart(with replacement: String) {
        if let text = customCurrentWord {
            // Use unicodeScalars.count: iOS deleteBackward() removes one scalar
            // at a time for Shan combining characters (e.g. "ၢ").
            deleteBackward(times: text.unicodeScalars.count)
        }
        insertText(replacement)
    }
}
