//
//  MaintenanceRecord.swift
//  NativeMaintenanceNote
//

import Foundation
import SwiftData

@Model
final class MaintenanceRecord {
    var id: UUID
    var bike: Bike?
    var part: MaintenancePart?
    var title: String
    var maintenanceDate: Date
    var price: Int
    var mileage: Int?
    var imageFilenames: [String]
    var memo: String

    init(
        id: UUID = UUID(),
        bike: Bike?,
        part: MaintenancePart?,
        title: String,
        maintenanceDate: Date = Date(),
        price: Int = 0,
        mileage: Int? = nil,
        imageFilenames: [String] = [],
        memo: String = ""
    ) {
        self.id = id
        self.bike = bike
        self.part = part
        self.title = title
        self.maintenanceDate = maintenanceDate
        self.price = price
        self.mileage = mileage
        self.imageFilenames = imageFilenames
        self.memo = memo
    }
}
