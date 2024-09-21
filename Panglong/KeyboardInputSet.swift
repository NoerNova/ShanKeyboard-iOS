//
//  KeyboardInputSet.swift
//  Panglong_iKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import KeyboardKit

public extension InputSet {
    static var panglong: InputSet {
        .init(rows: [
            .init(chars: "ၸတၼမႄပၵငသၺ"),
            .init(chars: "ေျိ်ႂႉႈုူး"),
            .init(chars: "ၽထၶလႇဢၢယ")
        ])
    }
}
