//
//  ShanKeyboardShared.swift
//  ShanKeyboardShared
//
//  Created by NorHsangPha BoonHse on 28/7/2568 BE.
//

import Foundation

public enum KeyboardInputSetLayout: String, CaseIterable {
    case panglong = "Panglong"
    case shanSIL = "Shan (SIL)"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var description: String {
        switch self {
        case .panglong:
            return "Panglong keyboard layout (Old)"
        case .shanSIL:
            return "Shan Standard Input Layout (SIL)"
        }
    }
}

// MARK: - Shared Constants
public struct AppGroupConstants {
    static let appGroupIdentifier = "group.com.noernova.ShanKeyboard.shared"
    static let keyboardLayoutKey = "selectedKeyboardLayout"
}

// MARK: - Shared UserDefaults Manager
public class SharedUserDefaults {
    public static let shared = SharedUserDefaults()
    
    private let userDefaults: UserDefaults
    
    private init() {
        self.userDefaults = UserDefaults(suiteName: AppGroupConstants.appGroupIdentifier) ?? .standard
    }
    
    public var keyboardLayout: KeyboardInputSetLayout {
        get {
            let savedValue = userDefaults.string(forKey: AppGroupConstants.keyboardLayoutKey)
            
            if let savedValue = savedValue {
                return KeyboardInputSetLayout(rawValue: savedValue) ?? .panglong
            } else {
                return .panglong
            }
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: AppGroupConstants.keyboardLayoutKey)
            userDefaults.synchronize() // Force synchronization
        }
    }
}
