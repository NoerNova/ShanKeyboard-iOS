//
//  StyleProvider.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 19/9/2567 BE.
//

import KeyboardKit
import SwiftUI

class StyleProvider: KeyboardStyle.StandardStyleService {
    
    let isIPad = UIDevice.current.userInterfaceIdiom == .pad
    
    override func buttonKeyboardFont(for action: KeyboardAction) -> KeyboardFont {
        switch action {
        case .character("ႂ်"):
            return isIPad ? KeyboardFont.custom("Shan", size: 22) : KeyboardFont.custom("Shan", size: 18)
        case .character:
            return isIPad ? KeyboardFont.custom("Shan", size: 24) : KeyboardFont.custom("Shan", size: 22)
        default:
            return KeyboardFont.system(size: buttonFontSize(for: action))
        }
    }
    
//    override func buttonContentInsets(for action: KeyboardAction) -> EdgeInsets {
//        switch action {
//            case .character("?"):
//                return EdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 22)
//            default:
//                return action.standardButtonContentInsets(for: keyboardContext)
//        }
//    }
    
    /// Fixed shift incorrect isPressed color
    override func buttonForegroundColor(for action: KeyboardAction, isPressed: Bool) -> Color {
        if #available(iOS 26.0, *) {
            switch action {
            case .shift:
                return isPressed ? Color.secondary : Color.primary
            default:
                return action.standardButtonForegroundColor(for: keyboardContext, isPressed: isPressed)
            }
        } else {
            // Fallback for < iOS 26
            return action.standardButtonForegroundColor(for: keyboardContext, isPressed: isPressed)
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
