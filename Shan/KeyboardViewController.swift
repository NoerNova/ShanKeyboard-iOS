//
//  KeyboardViewController.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import KeyboardKit
import ISEmojiView
import SwiftUI

class KeyboardViewController: ShanKeyboardInputViewController {
    
    override func viewDidLoad() {
        setupServices()
        setupState()
        
        super.viewDidLoad()
    }
    
    override func viewWillSetupKeyboardView() {
        super.viewWillSetupKeyboardView()
        
        setupKeyboardView { controller in KeyboardView(
            state: controller.state,
            services: controller.services,
            buttonContent: { $0.view },
            buttonView: { $0.view },
            collapsedView: { $0.view },
            emojiKeyboard: { $0.view },
            toolbar: { params in KeyboardToolbar(params: params.view, textDocumentProxy: controller.textDocumentProxy, keyboardController: controller)}
        )}
    }
}

extension KeyboardViewController {
    
    func setupServices() {
        
        let autocompleteProvider = AutocompleteServiceProvider(context: state.autocompleteContext)
        autocompleteProvider.onNgramModelLoaded = { [weak self] in
            self?.performAutocomplete()
        }
        services.autocompleteService = autocompleteProvider
        
        services.layoutService = LayoutServiceProvider()
        services.styleService = StyleProvider(keyboardContext: state.keyboardContext)
        services.calloutService = CalloutProvider()
        services.keyboardBehavior = BehaviorProvider(keyboardContext: state.keyboardContext)
        services.actionHandler = ActionHandlerProvider(controller: self)
    }
    
    func setupState() {
        state.keyboardContext.localePresentationLocale = .current
        
        state.keyboardContext.settings.spaceLongPressBehavior = .moveInputCursor
        state.keyboardContext.settings.isAutocapitalizationEnabled = false
        state.keyboardContext.settings.locale = KeyboardLocale.shan.locale
    }
}
