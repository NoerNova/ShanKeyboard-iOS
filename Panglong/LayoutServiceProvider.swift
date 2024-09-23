//
//  LayoutService.swift
//  Panglong_iKeyboard
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
            symbolicInputSet: .symbolic(currencies: ["$", "฿", "¥"])
        )
    }
    
    public lazy var iPadService: KeyboardLayoutService = CustomIPadService(alphabeticInputSet: .panglong, numericInputSet: .shanNumeric, symbolicInputSet: .symbolic(currencies: ["$", "฿", "¥"]))
    
    public lazy var iPhoneService: KeyboardLayoutService = CustomIPhoneService(alphabeticInputSet: .panglong, numericInputSet: .shanNumeric, symbolicInputSet: .symbolic(currencies: ["$", "฿", "¥"]))
    
    override func keyboardLayout(for context: KeyboardContext) -> KeyboardLayout {
        let service = keyboardLayoutService(for: context)
        let layout = service.keyboardLayout(for: context)
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
