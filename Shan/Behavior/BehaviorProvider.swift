//
//  Behavior.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 20/9/2567 BE.
//

import KeyboardKit
import UIKit

class BehaviorProvider: Keyboard.StandardBehavior {
    
    override init(keyboardContext: KeyboardContext, doubleTapThreshold: TimeInterval = 0.5, endSentenceText: String = "။ ", endSentenceThreshold: TimeInterval = 3.0, repeatGestureTimer: GestureButtonTimer = .init()) {
        super.init(
            keyboardContext: keyboardContext,
            doubleTapThreshold: doubleTapThreshold,
            endSentenceText: "။ ",
            endSentenceThreshold: endSentenceThreshold,
            repeatGestureTimer: repeatGestureTimer
        )
    }
    
    override func shouldSwitchToCapsLock(after gesture: Keyboard.Gesture, on action: KeyboardAction) -> Bool {
        return false
    }
}
