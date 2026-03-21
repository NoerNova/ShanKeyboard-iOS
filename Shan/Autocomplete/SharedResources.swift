//
//  SharedResources.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 10/3/2569 BE.
//

import Foundation

final class SharedResources {
    static let shared = SharedResources()

    let dictionaryService = DictionaryService()
    lazy var shanLanguageService: ShanLanguageService = ShanLanguageService()

    // Tokenizer already has its own singleton via Tokenizer.shared
    var tokenizer: Tokenizer { Tokenizer.shared }

    private init() {}
}
