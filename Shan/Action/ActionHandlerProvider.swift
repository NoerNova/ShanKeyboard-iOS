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
        
        /// prevent text replacement delete all text line - USE SHARED TOKENIZER
        return Tokenizer.shared.tokenize(prePost).last
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
        
        // If suggestion starts with input, it's a full word replacement
        if suggestionText.hasPrefix(inputText) { return false }
        
        // If we have a current word and suggestion doesn't contain it,
        // it's likely a completion suffix
        if let currentWord = customCurrentWord,
           !suggestionText.contains(currentWord),
           !suggestionText.hasPrefix(currentWord) {
            return true
        }
        
        return false
    }
    
    func customReplaceCurrentWordPreCursorPart(with replacement: String) {
        if let text = customCurrentWord {
            deleteBackward(times: (text as NSString).length)
        }
        insertText(replacement)
    }
}
