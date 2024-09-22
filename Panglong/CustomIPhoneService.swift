//
//  CustomIPhoneService.swift
//  Panglong_iKeyboard
//
//  Created by NorHsangPha BoonHse on 22/9/2567 BE.
//

import KeyboardKit

class CustomIPhoneService: KeyboardLayout.iPhoneService {
    override func characterItemSizeWidth(
         for action: KeyboardAction,
         row: Int,
         index: Int,
         context: KeyboardContext
     ) -> KeyboardLayout.ItemWidth {
         if isLastNumericInputRow(row, for: context) {
             return customLastSymbolicInputWidth(for: context)
         }
         return super.characterItemSizeWidth(for: action, row: row, index: index, context: context)
     }
     
     private func customLastSymbolicInputWidth(for context: KeyboardContext) -> KeyboardLayout.ItemWidth {
         // Your custom implementation here
         return .percentage(0.1) // Example: changed from 0.10 to 0.15
     }
     
     private func isLastNumericInputRow(_ row: Int, for context: KeyboardContext) -> Bool {
         let isNumeric = context.keyboardType == .numeric
         let isSymbolic = context.keyboardType == .symbolic
         guard isNumeric || isSymbolic else { return false }
         return row == 2 // Index 2 is the "wide keys" row
     }
}
