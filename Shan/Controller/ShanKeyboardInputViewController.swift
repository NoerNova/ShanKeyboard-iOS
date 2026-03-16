//
//  ShanKeyboardInputViewController.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 24/9/2567 BE.
//

import KeyboardKit
import UIKit

class ShanKeyboardInputViewController: KeyboardInputViewController {

    override var autocompleteText: String? {
        let text = textDocumentProxy.currentWordPreCursorPart ?? ""

        if text.isEmpty {
            return ""
        }

        // Return the raw text — let individual services handle word extraction.
        // Using Tokenizer here breaks incomplete words (e.g. "ၵုမ" → "မ").
        return text
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        AutocompleteServiceProvider.isSensitiveTextField =
            textDocumentProxy.isSecureTextEntry == true || isSensitiveContentType()

        // Keep context window in sync with what the user actually typed,
        // not just words selected from the suggestion bar.
        if let provider = services.autocompleteService as? AutocompleteServiceProvider,
           !AutocompleteServiceProvider.isSensitiveTextField {
            let documentContext = textDocumentProxy.documentContextBeforeInput ?? ""
            // Pass the partial word being typed so it can be stripped from context.
            let partialWord = textDocumentProxy.currentWordPreCursorPart ?? ""
            provider.updateContextFromDocument(documentContext, partialWord: partialWord)
        }
    }

    private func isSensitiveContentType() -> Bool {
        guard let contentType = textDocumentProxy.textContentType else { return false }
        switch contentType {
        case .password, .newPassword, .oneTimeCode,
             .creditCardNumber, .creditCardName, .creditCardGivenName,
             .creditCardMiddleName, .creditCardFamilyName, .creditCardExpiration,
             .creditCardType:
            return true
        default:
            return false
        }
    }
}

