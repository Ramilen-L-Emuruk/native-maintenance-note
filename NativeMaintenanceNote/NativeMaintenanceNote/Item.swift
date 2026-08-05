//
//  Item.swift
//  NativeMaintenanceNote
//
//  Created by 西辻怜央 on 2026/08/06.
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
