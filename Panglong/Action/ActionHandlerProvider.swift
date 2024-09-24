//
//  ActionHandler.swift
//  Panglong_iKeyboard
//
//  Created by NorHsangPha BoonHse on 20/9/2567 BE.
//

import KeyboardKit
import UIKit

class ActionHandlerProvider: KeyboardAction.StandardHandler {
    
    override func handle(
        _ suggestion: Autocomplete.Suggestion
    ) {
        tryAutolearnSuggestion(suggestion)
        keyboardContext.customInsertAutocompleteSuggestion(suggestion)
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
        keyboardContext.customInsertAutocompleteSuggestion(suggestion, tryInsertSpage: false)
    }
}

private extension KeyboardContext {
    
    func customInsertAutocompleteSuggestion(
        _ suggestion: Autocomplete.Suggestion,
        tryInsertSpage: Bool = false
    ) {
        #if os(iOS) || os(tvOS) || os(visionOS)
        textDocumentProxy.customInsertAutocompleteSuggestion(
            suggestion,
            tryInsertSpace: tryInsertSpage)
        #endif
    }
    
}

private extension UITextDocumentProxy {
    
    var customCurrentWord: String? {
        let pre = currentWordPreCursorPart
        let post = currentWordPostCursorPart
        if pre == nil && post == nil { return nil }
        
        let prePost = (pre ?? "") + (post ?? "")
        
        /// prevent text replacement delete all text line
        let tokenizer = Tokenizer()
        return tokenizer.tokenize(prePost).last
    }
    
    func customInsertAutocompleteSuggestion(
        _ suggestion: Autocomplete.Suggestion,
        tryInsertSpace: Bool = true
    ) {
        customReplaceCurrentWordPreCursorPart(with: suggestion.text)
        guard tryInsertSpace else { return }
        tryInsertSpaceAfterAutocomplete()
    }
    
    func customReplaceCurrentWordPreCursorPart(with replacement: String) {
        if let text = customCurrentWord {
            deleteBackward(times: (text as NSString).length)
        }
        insertText(replacement)
    }
}
