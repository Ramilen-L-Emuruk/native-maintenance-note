//
//  MaintenancePart.swift
//  NativeMaintenanceNote
//

import Foundation
import SwiftData

@Model
final class MaintenancePart {
    var id: UUID
    var type: MaintenanceType?
    var name: String
    var intervalDays: Int?
    var intervalDistance: Int?
    var notification: Bool
    var isSeeded: Bool

    init(
        id: UUID = UUID(),
        type: MaintenanceType?,
        name: String,
        intervalDays: Int? = nil,
        intervalDistance: Int? = nil,
        notification: Bool = false,
        isSeeded: Bool = false
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.intervalDays = intervalDays
        self.intervalDistance = intervalDistance
        self.notification = notification
        self.isSeeded = isSeeded
    }
}
