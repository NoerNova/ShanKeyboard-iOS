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

    /// Height stays at the 48pt default —
    /// anything lower clips the pill and the key-press callouts. KeyboardView
    /// prefers this service style over the environment.
    /// No highlighted autocorrect pill: the native bar highlights only real
    /// autocorrections, and suggestions here are predictions, not corrections.
    /// (Suggestions are no longer tagged .autocorrect either, so the
    /// autocorrectItem style only matters if that tag ever comes back.)
    override var autocompleteToolbarStyle: Autocomplete.ToolbarStyle {
        .init(
            item: .init(titleFont: .custom("Shan", size: 17)),
            autocorrectItem: .init(titleFont: .custom("Shan", size: 17))
        )
    }

    /// Shan font in the key-press balloon (bigger than the .largeTitle default)
    /// and in the long-press alternate callouts; everything else stays standard.
    ///
    /// On iOS 27 KeyboardKit draws callouts as floating bubbles (see
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

    /// On iOS 26 liquid glass, KeyboardKit's pressed state is only
    /// idle.opacity(0.6), so function keys (shift, backspace, ABC/123) barely
    /// change on tap. Mirror the classic native flash instead: white in light
    /// mode, lighter gray in dark mode.
    override func buttonBackgroundColor(for action: KeyboardAction, isPressed: Bool) -> Color {
        // iOS 27 lightens a pressed input key (it stays visible below the
        // floating callout); KeyboardKit's liquid-glass default dims it.
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
