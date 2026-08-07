//
//  InsuranceType.swift
//  NativeMaintenanceNote
//

import Foundation
import SwiftData

@Model
final class InsuranceType {
    var id: UUID
    @Attribute(.unique) var name: String
    var notification: Bool
    var isSeeded: Bool

    @Relationship(deleteRule: .cascade, inverse: \InsuranceRecord.type)
    var records: [InsuranceRecord] = []

    init(id: UUID = UUID(), name: String, notification: Bool = false, isSeeded: Bool = false) {
        self.id = id
        self.name = name
        self.notification = notification
        self.isSeeded = isSeeded
    }
}
