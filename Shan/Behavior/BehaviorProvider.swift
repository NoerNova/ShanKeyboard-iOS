//
//  Behavior.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 20/9/2567 BE.
//

import KeyboardKit
import UIKit

class BehaviorProvider: Keyboard.StandardKeyboardBehavior {
    
    override init(keyboardContext: KeyboardContext, doubleTapThreshold: TimeInterval? = 0.5, endSentenceText: String? = "။ ", endSentenceThreshold: TimeInterval? = 0.5, repeatGestureTimer: GestureButtonTimer? = .init()) {
        super.init(
            keyboardContext: keyboardContext,
            doubleTapThreshold: doubleTapThreshold,
            endSentenceText: "။ ",
            // 0.5s so only a genuine quick double space-tap ends the sentence.
            // The base class's 3.0s default let a space typed seconds earlier
            // count as the first tap, firing "။ " on a single new space.
            endSentenceThreshold: 0.5,
            repeatGestureTimer: repeatGestureTimer
        )
    }

    override func shouldEndCurrentSentence(after gesture: Keyboard.Gesture, on action: KeyboardAction) -> Bool {
        // super also updates lastSpaceTap bookkeeping — always call it first.
        guard super.shouldEndCurrentSentence(after: gesture, on: action) else { return false }
        // Never stack a terminator: if the text before the trailing spaces already
        // ends with '။' or '၊', don't apply another (KeyboardKit's own check only
        // knows western sentence delimiters).
        let pre = keyboardContext.textDocumentProxy.documentContextBeforeInput ?? ""
        let beforeSpaces = String(pre.reversed().drop { $0 == " " }.reversed())
        return !beforeSpaces.hasSuffix("။") && !beforeSpaces.hasSuffix("၊")
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
