//
//  KeyboardInputSet.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import KeyboardKit

public extension InputSet {
    static var panglong: InputSet {
        .init(rows: [
            .init(lowercased: ["ၸ", "တ", "ၼ", "မ", "ႄ", "ပ", "ၵ", "င", "သ", "ၺ"], uppercased: ["ၹ", "ၻ", "ꧣ", "႞", "ၿ", "ြ", "ၷ", "ႀ", "ဝ", "ႁ"]),
            .init(lowercased: ["ေ", "ျ", "ိ", "်", "ႂ", "ႉ", "ႈ", "ု", "ူ", "း"], uppercased: ["ဵ", "ှ", "ီ", "ႅ", "ႂ်", "ံ", "့", "ရ", "႟", "ႊ"]),
            .init(lowercased: ["ၽ", "ထ", "ၶ", "လ", "ႇ", "ဢ", "ၢ", "ယ"], uppercased: ["ၾ", "ၻ", "ꧠ", "ꩮ", "ႆ", "ွ", "ႃ", "ꧦ"])
        ])
    }
    
    static var shanNumeric: InputSet {
        .init(rows: [
            .init(chars: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
            .init(phone: "-/:;()$&@”", pad: "@#$&*()’”"),
            .init(phone: ".,?!’၊။", pad: "%-+=/;:!?")
        ])
    }
}
