//
//  LayoutService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 19/9/2567 BE.
//

import KeyboardKit
import SwiftUI

class LayoutServiceProvider: KeyboardLayout.BaseService, LocalizedService {
    
    var localeKey: String = KeyboardLocale.shan.id
    
    init() {
        super.init(
            alphabeticInputSet: .panglong,
            numericInputSet: .shanNumeric,
            symbolicInputSet: .shanSymbolic(currencies: ["$", "฿", "¥"])
        )
    }
    
    public lazy var iPadService: KeyboardLayoutService = CustomIPadService(alphabeticInputSet: .panglong, numericInputSet: .shanNumeric, symbolicInputSet: .shanSymbolic(currencies: ["$", "฿", "¥"]))
    
    public lazy var iPhoneService: KeyboardLayoutService = CustomIPhoneService(alphabeticInputSet: .panglong, numericInputSet: .shanNumeric, symbolicInputSet: .shanSymbolic(currencies: ["$", "฿", "¥"]))
    
    override func keyboardLayout(for context: KeyboardContext) -> KeyboardLayout {
        let service = keyboardLayoutService(for: context)
        let layout = service.keyboardLayout(for: context)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            layout.tryInsertPunctuations(.character("။"))
            layout.tryInsertPunctuations(.character("၊"))
        }
        
        return layout
    }
    
    func keyboardLayoutService(
        for context: KeyboardContext
    ) -> KeyboardLayoutService {
        switch context.deviceType {
        case .phone: iPhoneService
        case .pad: iPadService
        default: iPhoneService
        }
    }
}

private extension KeyboardLayout {
    func tryInsertPunctuations(_ action: KeyboardAction) {
        guard let item = tryCreateBottomRowItem(for: action) else { return }
        itemRows.insert(item, after: .space, atRow: bottomRowIndex)
    }
}
