//
//  Item.swift
//  Plano
//
//  Created by Niven Sivarajah on 2026-03-05.
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
