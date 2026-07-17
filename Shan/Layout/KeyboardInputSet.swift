//
//  KeyboardInputSet.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import KeyboardKit

public extension KeyboardLayout.InputSet {
    // MARK: - Panglong Layout
    static var panglong: KeyboardLayout.InputSet {
        .init(rows: [
            .init(lowercased: ["ၸ", "တ", "ၼ", "မ", "ႄ", "ပ", "ၵ", "င", "သ", "ၺ"], uppercased: ["ၹ", "ၻ", "ꧣ", "႞", "ၿ", "ြ", "ၷ", "ႀ", "ဝ", "ႁ"]),
            .init(lowercased: ["ေ", "ျ", "ိ", "်", "ႂ", "ႉ", "ႈ", "ု", "ူ", "း"], uppercased: ["ဵ", "ှ", "ီ", "ႅ", "ႂ်", "ံ", "့", "ရ", "႟", "ႊ"]),
            .init(lowercased: ["ၽ", "ထ", "ၶ", "လ", "ႇ", "ဢ", "ၢ", "ယ"], uppercased: ["ၾ", "ၻ", "ꧠ", "ꩮ", "ႆ", "ွ", "ႃ", "ꧦ"])
        ])
    }
    
    static var panglongNumeric: KeyboardLayout.InputSet {
        .init(rows: [
            .init(chars: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
            .init(chars: "-/:;()$&@”", deviceVariations: [.pad: "@#$&*()’”"]),
            .init(chars: ".,?!’၊။", deviceVariations: [.pad: "%-+=/;:!?"]),
        ])
    }
    
    static func panglongSymbolic(currencies: [String]) -> KeyboardLayout.InputSet {
        .init(rows: [
            .init(chars: "[]{}#%^*+=", deviceVariations: [.pad: "႑႒႓႔႕႖႗႘႙႐"]),
            .init(
                chars: "_\\|~<>\(currencies.joined())•",
                deviceVariations: [.pad: "\(currencies.joined())_^[]{}"]),
            .init(chars: "×÷.,?!’", deviceVariations: [.pad: "§|~…\\<>!?"])
        ])
    }
    
    // MARK: - Shan Standard Layout
    static var shanSIL: KeyboardLayout.InputSet {
        .init(rows: [
            .init(lowercased: ["ၸ", "တ", "ၼ", "မ", "ဢ", "ပ", "ၵ", "င", "ဝ", "ႁ"], uppercased: ["ꩡ", "ၻ", "ꧣ", "႞", "ြ", "ၿ", "ၷ", "ရ", "သ", "ႀ"]),
            .init(lowercased: ["ေ", "ႄ", "ိ", "်", "ွ", "ႉ", "ႇ", "ု", "ူ", "ႈ"], uppercased: ["ဵ", "ႅ", "ီ", "ႂ်", "ႂ", "့", "ႆ", "ံ", "ႊ", "း"]),
            .init(lowercased: ["ၽ", "ထ", "ၶ", "လ", "ယ", "ၺ", "ၢ", "။"], uppercased: ["ၾ", "ꩪ", "ꧠ", "ꩮ", "ျ", "႟", "ႃ", "၊"], deviceVariations: [.pad: (lowercased: ["ၽ", "ထ", "ၶ", "လ", "ယ", "ၺ", "ၢ", ","], uppercased: ["ၾ", "ꩪ", "ꧠ", "ꩮ", "ျ", "႟", "ႃ", "?"])]),
        ])
    }
    
    static var shanSILNumeric: KeyboardLayout.InputSet {
        .init(rows: [
            .init(chars: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
            .init(chars: "-/:;()$&@”", deviceVariations: [.pad: "@#$&*()’”"]),
            .init(chars: ".,?!’၊။", deviceVariations: [.pad: "%-+=/;:!?"])
        ])
    }
    
    static func shanSILSymbolic(currencies: [String]) -> KeyboardLayout.InputSet {
        .init(rows: [
            .init(chars: "[]{}#%^*+=", deviceVariations: [.pad: "႑႒႓႔႕႖႗႘႙႐"]),
            .init(
                chars: "_\\|~<>\(currencies.joined())•",
                deviceVariations: [.pad: "\(currencies.joined())_^[]{}"]),
            .init(chars: "×÷.,?!’", deviceVariations: [.pad: "§|~…\\<>!?"])
        ])
    }
}
