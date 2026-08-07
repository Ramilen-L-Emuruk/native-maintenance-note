//
//  Maker.swift
//  NativeMaintenanceNote
//

import Foundation
import SwiftData

@Model
final class Maker {
    var id: UUID
    @Attribute(.unique) var name: String
    var isSeeded: Bool

    init(id: UUID = UUID(), name: String, isSeeded: Bool = false) {
        self.id = id
        self.name = name
        self.isSeeded = isSeeded
    }
}
