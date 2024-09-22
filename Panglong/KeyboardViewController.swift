//
//  KeyboardViewController.swift
//  Panglong
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import KeyboardKit
import ISEmojiView
import SwiftUI

class KeyboardViewController: KeyboardInputViewController {
    
    override func viewDidLoad() {
        setupServices()
        setupState()
        
        super.viewDidLoad()
    }
    
    override func viewWillSetupKeyboard() {
        super.viewWillSetupKeyboard()
        
        setup { controller in KeyboardView(
            state: controller.state,
            services: controller.services,
            buttonContent: { $0.view },
            buttonView: { $0.view },
            emojiKeyboard: { $0.view },
            toolbar: { params in params.view }
        )}
    }
}

extension KeyboardViewController {
    
    func setupServices() {
        
        services.autocompleteService = AutocompleteServiceProvider(context: state.autocompleteContext)
        
        services.layoutService = LayoutServiceProvider()
        services.styleProvider = StyleProvider(keyboardContext: state.keyboardContext)
        services.calloutService = CalloutProvider()
    }
    
    func setupState() {
        state.keyboardContext.spaceLongPressBehavior = .moveInputCursor
        
        state.keyboardContext.localePresentationLocale = .current
        state.keyboardContext.locale = KeyboardLocale.english.locale
    }
}
