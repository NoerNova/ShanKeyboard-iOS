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

    override var autocompleteToolbarStyle: Autocomplete.ToolbarStyle {
        .init(
            item: .init(titleFont: .custom("Shan", size: 17)),
            autocorrectItem: .init(titleFont: .custom("Shan", size: 17))
        )
    }

    override var calloutStyle: Callouts.CalloutStyle? {
        let actionItemFont = KeyboardFont.custom("Shan", size: 22)
        let inputItemFont = KeyboardFont.custom("Shan", size: 32)
        guard #available(iOS 27.0, *) else {
            return .init(actionItemFont: actionItemFont, inputItemFont: inputItemFont)
        }
        let isDark = keyboardContext.colorScheme == .dark
        return .init(
            appearance: .floating,
            actionItemFont: actionItemFont,
            backgroundColor: isDark ? Color(white: 0.29) : .white,
            borderColor: isDark ? .white.opacity(0.06) : .black.opacity(0.03),
            foregroundColor: .primary,
            inputItemFont: inputItemFont,
            selectedBackgroundColor: isDark ? .white.opacity(0.08) : Color(white: 0.894),
            selectedForegroundColor: .primary,
            shadowColor: .black.opacity(isDark ? 0.25 : 0.12),
            shadowRadius: 6
        )
    }

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

    override func buttonBackgroundColor(for action: KeyboardAction, isPressed: Bool) -> Color {
        
        if #available(iOS 26.0, *), isPressed, action == .backspace {
            guard keyboardContext.colorScheme == .dark else {
                return Color(red: 0.773, green: 0.773, blue: 0.788)
            }
            if #available(iOS 27.0, *) { return Color(white: 0.51) }
            return Color(white: 0.49)
        }
        
        if #available(iOS 27.0, *), isPressed, action.hasIOS27PressedHighlight {
            return keyboardContext.colorScheme == .dark
                ? Color(white: 0.41)
                : Color(white: 0.894)
        }
        if #available(iOS 26.0, *), isPressed, action.isSystemAction {
            return keyboardContext.colorScheme == .dark
                ? Color.keyboardButtonBackground(for: .dark)
                : .white
        }
        return super.buttonBackgroundColor(for: action, isPressed: isPressed)
    }

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

    /// Keys that get the lighter iOS 27 pressed color.
    var hasIOS27PressedHighlight: Bool {
        switch self {
        case .character, .diacritic, .space, .text: true
        default: false
        }
    }
}
