//
//  Item.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
