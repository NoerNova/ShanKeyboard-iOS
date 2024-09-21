//
//  LayoutService.swift
//  Panglong_iKeyboard
//
//  Created by NorHsangPha BoonHse on 19/9/2567 BE.
//

import KeyboardKit

class LayoutService: KeyboardLayout.DeviceBasedService {
    
    init(extraKey: ExtraKey) {
        self.extraKey = extraKey
        super.init(
            alphabeticInputSet: .panglong,
            numericInputSet: .shanNumeric,
            symbolicInputSet: .symbolic(currencies: ["$", "฿", "¥"])
        )
    }
    
    let extraKey: ExtraKey
    
    enum ExtraKey {
        case none
        case emojiIfNeeded
        case keyboardSwitcher
        case localeSwitcher
        case url(String)
    }
    
    override func keyboardLayout(for context: KeyboardContext) -> KeyboardLayout {
        let layout = super.keyboardLayout(for: context)
        
        switch extraKey {
        case .none:
            break
        case .emojiIfNeeded:
            layout.tryInsertEmojiButton()
        case .keyboardSwitcher:
            layout.tryInsert(.nextKeyboard)
        case .localeSwitcher:
            layout.tryInsert(.nextLocale)
        case .url(let string):
            layout.tryInsert(.url(.init(string: string), id: nil))
        }
        
        return layout
    }
    
}

private extension KeyboardLayout {
    func tryInsert(_ action: KeyboardAction) {
        guard let item = tryCreateBottomRowItem(for: action) else { return }
        itemRows.insert(item, before: .space, atRow: bottomRowIndex)
    }
    
    func tryInsertEmojiButton() {
        guard let row = bottomRow else { return }
        let hasEmoji = row.contains(where: { $0.action == .keyboardType(.emojis) })
        if hasEmoji { return }
        guard let button = tryCreateBottomRowItem(for: .keyboardType(.emojis)) else { return }
        itemRows.insert(button, after: .space, atRow: bottomRowIndex)
    }
}
