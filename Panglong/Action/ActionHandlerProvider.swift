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
    
    /// The word segment before the cursor location, if any.
    var customCurrentWordPreCursorPart: String? {
        guard let textBeforeCursor = documentContextBeforeInput else { return nil }
        let tokenizedWords = Tokenizer.tokenize(textBeforeCursor)
        return tokenizedWords.last // Get the last token before the cursor
    }

    /// The word segment after the cursor location, if any.
    var customCurrentWordPostCursorPart: String? {
        guard let textAfterCursor = documentContextAfterInput else { return nil }
        let tokenizedWords = Tokenizer.tokenize(textAfterCursor)
        return tokenizedWords.first // Get the first token after the cursor
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
        if let text = customCurrentWordPreCursorPart {
            deleteBackward(times: (text as NSString).length)
        }
        insertText(replacement)
    }
}
