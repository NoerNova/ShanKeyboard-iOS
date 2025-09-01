//
//  Behavior.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 20/9/2567 BE.
//

import KeyboardKit
import UIKit

class BehaviorProvider: Keyboard.StandardKeyboardBehavior {
    
    override init(keyboardContext: KeyboardContext, doubleTapThreshold: TimeInterval? = 0.5, endSentenceText: String? = "။ ", endSentenceThreshold: TimeInterval? = 3.0, repeatGestureTimer: GestureButtonTimer? = .init()) {
        super.init(
            keyboardContext: keyboardContext,
            doubleTapThreshold: doubleTapThreshold,
            endSentenceText: "။ ",
            endSentenceThreshold: endSentenceThreshold,
            repeatGestureTimer: repeatGestureTimer
        )
    }
    
    override func preferredKeyboardCase(after gesture: Keyboard.Gesture, on action: KeyboardAction) -> Keyboard.KeyboardCase {
        let current = keyboardContext.keyboardCase
        switch action {
        case .shift:
            guard gesture == .release else { return current }
            return isDoubleShiftTap ? .auto : current
        default:
            return .auto
        }
    }
}
