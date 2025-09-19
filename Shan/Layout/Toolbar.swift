//
//  Toolbar.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 14/9/2568 BE.
//

import SwiftUI
import KeyboardKit
import UIKit
import ShanKeyboardShared

public struct KeyboardToolbar: View {
    
    private var params: Autocomplete.Toolbar<Autocomplete.ToolbarItem, Autocomplete.ToolbarSeparator>
    private var textDocumentProxy: UITextDocumentProxy
    private var keyboardController: KeyboardController
    
    init(
        params: Autocomplete.Toolbar<Autocomplete.ToolbarItem, Autocomplete.ToolbarSeparator>,
        textDocumentProxy: UITextDocumentProxy,
        keyboardController: KeyboardController,
        
    ) {
        self.params = params
        self.textDocumentProxy = textDocumentProxy
        self.keyboardController = keyboardController
    }
    
    public var body: some View {
        HStack {
            if allowsAutocomplete() {
                params.autocompleteToolbarStyle(
                    .init(item:
                            .init(titleFont: .custom("Shan", size: 17))
                    )
                )
            } else {
                hideAutoCompleteView
            }
        }
    }
}

public extension KeyboardToolbar {
    var hideAutoCompleteView: some View {
        HStack {
            Spacer()
            Button {
                keyboardController.dismissKeyboard()
            } label: {
                Image(systemName: "chevron.down")
            }
            .font(Font.system(size: 20))
            .padding()
            .buttonStyle(.bordered)
        }
    }
}

public extension KeyboardToolbar {
    func allowsAutocomplete() -> Bool {
        // Check for secure text entry first
        if textDocumentProxy.isSecureTextEntry! {
            return false
        }
        
        if textDocumentProxy.autocorrectionType == .no {
            return false
        }
        
        // Check textContentType - these should show autocomplete/autofill
        if let contentType = textDocumentProxy.textContentType {
            switch contentType {
            // Contact Information
            case .name, .namePrefix, .givenName, .middleName, .familyName, .nameSuffix,
                 .nickname, .emailAddress, .telephoneNumber, .organizationName, .jobTitle,
            // Address Information
                 .fullStreetAddress, .streetAddressLine1, .streetAddressLine2,
                 .addressCity, .addressState, .addressCityAndState, .sublocality,
                 .countryName, .postalCode:
                return true
            // Financial Information
            case
                 .creditCardNumber, .creditCardName, .creditCardGivenName,
                 .creditCardMiddleName, .creditCardFamilyName, .creditCardExpiration,
                 .creditCardType:
                return false
                
            // Security fields - suppress autocomplete
            case .password, .newPassword:
                return false
                
            // One-time codes - suppress autocomplete
            case .oneTimeCode:
                return false
                
            // Other specific types that typically don't have autocomplete
            case .flightNumber, .shipmentTrackingNumber:
                return false
                
            case .some(_):
                return true
            case .none:
                return true
            @unknown default:
                // For unknown content types, fall back to keyboard type check
                break
            }
        }
        
        // Fall back to keyboard type check for unspecified content types
        switch textDocumentProxy.keyboardType {
        case .default,
             .asciiCapable,
             .numbersAndPunctuation,
             .emailAddress,
             .URL,
             .twitter,
             .asciiCapableNumberPad:
            return true
            
        case .numberPad,
             .decimalPad,
             .phonePad,
             .webSearch,
             .namePhonePad:
            return false
            
        case .none:
            return false
        @unknown default:
            return false
        }
    }
}
