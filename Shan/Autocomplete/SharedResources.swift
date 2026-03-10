//
//  SharedResources.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 10/3/2569 BE.
//

import Foundation

final class SharedResources {
    static let shared = SharedResources()

    lazy var dictionaryService: DictionaryService = DictionaryService()
    lazy var shanLanguageService: ShanLanguageService = ShanLanguageService()

    // Tokenizer already has its own singleton via Tokenizer.shared
    var tokenizer: Tokenizer { Tokenizer.shared }

    private init() {}
}
