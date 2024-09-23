//
//  CustomIPhoneService.swift
//  Panglong_iKeyboard
//
//  Created by NorHsangPha BoonHse on 22/9/2567 BE.
//

import KeyboardKit

class CustomIPhoneService: KeyboardLayout.iPhoneService {
        
    override func itemSizeWidth(
        for action: KeyboardAction,
        row: Int,
        index: Int,
        context: KeyboardContext
    ) -> KeyboardLayout.ItemWidth {
        switch action {
        case context.keyboardDictationReplacement: bottomSystemButtonWidth(for: context)
        case .character: characterItemSizeWidth(for: action, row: row, index: index, context: context)
        case .backspace: lowerSystemButtonWidth(for: context)
        case .keyboardType: row == 2 ? lowerSystemButtonWidth(for: context) :  bottomSystemButtonWidth(for: context)
        case .nextKeyboard: bottomSystemButtonWidth(for: context)
        case .primary: .percentage(isPortrait(context) ? 0.25 : 0.195)
        case .shift: lowerSystemButtonWidth(for: context)
        default: .available
        }
    }
    
    override func characterItemSizeWidth(
         for action: KeyboardAction,
         row: Int,
         index: Int,
         context: KeyboardContext
     ) -> KeyboardLayout.ItemWidth {
         if isLastNumericInputRow(row, for: context) {
             return customLastSymbolicInputWidth(for: context)
         }
         if shouldUpdateUpperCharacterInputWidth(row, for: context) {
             return updateUpperCharacterInputWidth(for: context)
         }
         return super.characterItemSizeWidth(for: action, row: row, index: index, context: context)
     }
    
    /// Just change row=3 item width fixed most case
    override func lowerSystemButtonWidth(
        for context: KeyboardContext
    ) -> KeyboardLayout.ItemWidth {
        return .percentage(0.1)
    }

}

private extension CustomIPhoneService {
    
    func updateUpperCharacterInputWidth(for context: KeyboardContext) -> KeyboardLayout.ItemWidth {
        return .percentage(0.1)
    }
    
    func customLastSymbolicInputWidth(for context: KeyboardContext) -> KeyboardLayout.ItemWidth {
        // Your custom implementation here
        return .percentage(0.1) // Example: changed from 0.10 to 0.15
    }
    
    func shouldUpdateUpperCharacterInputWidth(_ row: Int, for context: KeyboardContext) -> Bool {
        let isCharacter = context.keyboardType.isAlphabetic
//        let isUpperRow = row == 0 || row == 1 || row == 2 || row == 3
        let isURL = context.textDocumentProxy.keyboardType == .URL
        guard isCharacter && !isURL else { return false }
        return true
    }
    
    func isLastNumericInputRow(_ row: Int, for context: KeyboardContext) -> Bool {
        let isNumeric = context.keyboardType == .numeric
        let isSymbolic = context.keyboardType == .symbolic
        guard isNumeric || isSymbolic else { return false }
        return row == 2 // Index 2 is the "wide keys" row
    }
    
    func isPortrait(
        _ context: KeyboardContext
    ) -> Bool {
        context.interfaceOrientation.isPortrait
    }

}
