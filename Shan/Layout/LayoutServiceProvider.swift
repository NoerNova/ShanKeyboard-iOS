//
//  LayoutService.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 19/9/2567 BE.
//

import KeyboardKit
import SwiftUI
import ShanKeyboardShared

class LayoutServiceProvider: KeyboardLayout.BaseService, LocalizedService {
    static let shared = LayoutServiceProvider()
    
    var localeKey: String = KeyboardLocale.shan.id
    
    init() {
        super.init(
            alphabeticInputSet: .panglong,
            numericInputSet: .panglongNumeric,
            symbolicInputSet: .panglongSymbolic(currencies: ["$", "฿", "¥"])
        )
    }
    
    var currentLayout: KeyboardInputSetLayout {
        return SharedUserDefaults.shared.keyboardLayout
    }
    
    public func getLayout() -> InputSet {
        switch currentLayout {
        case .panglong:
            return .panglong
        case .shanSIL:
            return .shanSIL
        @unknown default:
            return .panglong
        }
    }
    
    public func getNumericLayout() -> InputSet {
        switch currentLayout {
        case .panglong:
            return .panglongNumeric
        case .shanSIL:
            return .shanSILNumeric
        @unknown default:
            return .panglongNumeric
        }
    }
    
    public func getSymbolicLayout() -> InputSet {
        let currencies: [String] = ["$", "฿", "¥"]
        
        switch currentLayout {
        case .panglong:
            return .panglongSymbolic(currencies: currencies)
        case .shanSIL:
            return .shanSILSymbolic(currencies: currencies)
        @unknown default:
            return .panglongSymbolic(currencies: currencies)
        }
    }
    
    public lazy var iPadService: KeyboardLayoutService = CustomIPadService(alphabeticInputSet: getLayout(), numericInputSet: getNumericLayout(), symbolicInputSet: getSymbolicLayout())
    
    public lazy var iPhoneService: KeyboardLayoutService = CustomIPhoneService(alphabeticInputSet: getLayout(), numericInputSet: getNumericLayout(), symbolicInputSet: getSymbolicLayout())
    
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
