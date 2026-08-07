//
//  MaintenanceType.swift
//  NativeMaintenanceNote
//

import Foundation
import SwiftData

@Model
final class MaintenanceType {
    var id: UUID
    @Attribute(.unique) var name: String
    var isSeeded: Bool

    @Relationship(deleteRule: .cascade, inverse: \MaintenancePart.type)
    var parts: [MaintenancePart] = []

    init(id: UUID = UUID(), name: String, isSeeded: Bool = false) {
        self.id = id
        self.name = name
        self.isSeeded = isSeeded
    }
}
