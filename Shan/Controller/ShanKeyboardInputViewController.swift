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
        
        if let lastToken = Tokenizer.shared.getLastToken(from: text) {
            return lastToken
        }
        
        return text
    }
}

