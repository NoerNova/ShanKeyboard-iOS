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
}

