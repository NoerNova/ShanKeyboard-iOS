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
    override var autocompleteToolbarStyle: Autocomplete.ToolbarStyle {
        .init(
            item: .init(titleFont: .custom("Shan", size: 17)),
            autocorrectItem: .init(
                titleFont: .custom("Shan", size: 17),
                backgroundColor: Color(UIColor { trait in
                    trait.userInterfaceStyle == .dark
                        ? UIColor.white.withAlphaComponent(0.2)
                    : UIColor.white.withAlphaComponent(0.4)
                }),
                backgroundCornerRadius: 20
            )
        )
    }

    /// Shan font in the key-press balloon (bigger than the .largeTitle default)
    /// and in the long-press alternate callouts; everything else stays standard.
    override var calloutStyle: Callouts.CalloutStyle? {
        .init(
            actionItemFont: .custom("Shan", size: 22),
            inputItemFont: .custom("Shan", size: 32)
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
