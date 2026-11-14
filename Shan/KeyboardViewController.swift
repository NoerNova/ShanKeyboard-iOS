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
        // Before any view renders: turns the CALayerInvalidGeometry (NaN bounds)
        // crash into a logged, zero-sized frame. See LayerGeometryGuard.swift.
        LayerGeometryGuard.install()
        MemoryProbe.log("launch")
        setupServices()
        setupState()
        
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        MemoryProbe.log("memory warning")
        flushCaches()
        MemoryProbe.log("memory warning flushed")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Release the cheap-to-rebuild caches when the keyboard is dismissed so memory
        // doesn't accumulate across host-app switches. The dictionary and n-gram
        // model are memory-mapped files and cost no dirty memory, so they stay.
        flushCaches()
        MemoryProbe.log("dismissed")
    }

    private func flushCaches() {
        Tokenizer.shared.clearCache()
        if let provider = services.autocompleteService as? AutocompleteServiceProvider {
            provider.clearCaches()
        }
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
        autocompleteProvider.onModelLoaded = { [weak self] in
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
