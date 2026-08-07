//
//  Shop.swift
//  NativeMaintenanceNote
//

import Foundation
import SwiftData

@Model
final class Shop {
    var id: UUID
    @Attribute(.unique) var name: String
    var address: String
    var isSeeded: Bool

    init(id: UUID = UUID(), name: String, address: String = "", isSeeded: Bool = false) {
        self.id = id
        self.name = name
        self.address = address
        self.isSeeded = isSeeded
    }
}
