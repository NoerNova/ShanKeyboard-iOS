//
//  CustomIPadService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 22/9/2567 BE.
//

import KeyboardKit

class CustomIPadService: KeyboardLayout.iPadService {
    
    /// The bottom row actions.
    override func bottomActions(for context: KeyboardContext) -> KeyboardAction.Row {
        var result = KeyboardAction.Row()
        let needsDictation = context.needsInputModeSwitchKey
        
        result.append(.nextKeyboard)
        if let action = keyboardSwitchActionForBottomRow(for: context) { result.append(action) }
        if needsDictation, let action = context.keyboardDictationReplacement { result.append(action) }
        result.append(.space)
        if let action = keyboardSwitchActionForBottomRow(for: context) { result.append(action) }
        result.append(.dismissKeyboard)
        return result
    }
    
    open override func itemSizeWidth(
        for action: KeyboardAction,
        row: Int,
        index: Int,
        context: KeyboardContext
    ) -> KeyboardLayout.ItemWidth {
        if isLowerTrailingSwitcher(action, row: row, index: index) { return .available }
        switch action {
        case context.keyboardDictationReplacement: return .input
        case .none: return .inputPercentage(0.0001)
        case .primary: return .available
        case .backspace: return .inputPercentage(1.6)
        case .shift: return .inputPercentage(1.6225)
        default: break
        }
        if action.isSystemAction { return systemButtonWidth(for: context) }
        return super.itemSizeWidth(for: action, row: row, index: index, context: context)
    }
}

extension CustomIPadService {
    func isLowerTrailingSwitcher(
        _ action: KeyboardAction,
        row: Int,
        index: Int
    ) -> Bool {
        switch action {
        case .shift, .keyboardType: row == 2 && index > 0
        default: false
        }
    }
}
