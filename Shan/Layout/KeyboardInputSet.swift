//
//  KeyboardInputSet.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import KeyboardKit

public extension InputSet {
    // MARK: - Panglong Layout
    static var panglong: InputSet {
        .init(rows: [
            .init(lowercased: ["ၸ", "တ", "ၼ", "မ", "ႄ", "ပ", "ၵ", "င", "သ", "ၺ"], uppercased: ["ၹ", "ၻ", "ꧣ", "႞", "ၿ", "ြ", "ၷ", "ႀ", "ဝ", "ႁ"]),
            .init(lowercased: ["ေ", "ျ", "ိ", "်", "ႂ", "ႉ", "ႈ", "ု", "ူ", "း"], uppercased: ["ဵ", "ှ", "ီ", "ႅ", "ႂ်", "ံ", "့", "ရ", "႟", "ႊ"]),
            .init(lowercased: ["ၽ", "ထ", "ၶ", "လ", "ႇ", "ဢ", "ၢ", "ယ"], uppercased: ["ၾ", "ၻ", "ꧠ", "ꩮ", "ႆ", "ွ", "ႃ", "ꧦ"])
        ])
    }
    
    static var panglongNumeric: InputSet {
        .init(rows: [
            .init(chars: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
            .init(phone: "-/:;()$&@”", pad: "@#$&*()’”"),
            .init(phone: ".,?!’၊။", pad: "%-+=/;:!?")
        ])
    }
    
    static func panglongSymbolic(currencies: [String]) -> InputSet {
        .init(rows: [
            .init(phone: "[]{}#%^*+=", pad: "႑႒႓႔႕႖႗႘႙႐"),
            .init(
                phone: "_\\|~<>\(currencies.joined())•",
                pad: "\(currencies.joined())_^[]{}"),
            .init(phone: ".,?!’", pad: "§|~…\\<>!?")
        ])
    }
    
    // MARK: - Shan Standard Layout
    static var shanSIL: InputSet {
        .init(rows: [
            .init(lowercased: ["ၸ", "တ", "ၼ", "မ", "ဢ", "ပ", "ၵ", "င", "ဝ", "ႁ"], uppercased: ["ꩡ", "ၻ", "ꧣ", "႞", "ြ", "ၿ", "ၷ", "ရ", "သ", "ႀ"]),
            .init(lowercased: ["ေ", "ႄ", "ိ", "်", "ွ", "ႉ", "ႇ", "ု", "ူ", "ႈ"], uppercased: ["ဵ", "ႅ", "ီ", "ႂ်", "ႂ", "့", "ႆ", "\"", "ႊ", "း"]),
            .init(lowercased: ["ၽ", "ထ", "ၶ", "လ", "ယ", "ၺ", "ၢ", "။"], uppercased: ["ၾ", "ꩪ", "ꧠ", "ꩮ", "ျ", "႟", "ႃ", "ꧦ"])
        ])
    }
    
    static var shanSILNumeric: InputSet {
        .init(rows: [
            .init(chars: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
            .init(phone: "-/:;()$&@”", pad: "@#$&*()’”"),
            .init(phone: ".,?!’၊။", pad: "%-+=/;:!?")
        ])
    }
    
    static func shanSILSymbolic(currencies: [String]) -> InputSet {
        .init(rows: [
            .init(phone: "[]{}#%^*+=", pad: "႑႒႓႔႕႖႗႘႙႐"),
            .init(
                phone: "_\\|~<>\(currencies.joined())•",
                pad: "\(currencies.joined())_^[]{}"),
            .init(phone: ".,?!’", pad: "§|~…\\<>!?")
        ])
    }
}
