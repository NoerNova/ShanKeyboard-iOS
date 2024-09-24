//
//  StyleProvider.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 19/9/2567 BE.
//

import KeyboardKit
import SwiftUI

class StyleProvider: KeyboardStyle.StandardProvider {
    
    override func buttonKeyboardFont(for action: KeyboardAction) -> KeyboardFont {
        switch action {
        case .character("ႂ်"):
            return KeyboardFont.custom("Shan", size: 18)
        case .character:
            return KeyboardFont.custom("Shan", size: 22)
        default:
            return KeyboardFont.system(size: buttonFontSize(for: action))
        }
    }
}

private extension KeyboardAction {
    
    var fontScaleFactor: Double {
        return 1.0
    }
    
    var replacementAction: KeyboardAction? {
        return .primary(.continue)
    }
}
