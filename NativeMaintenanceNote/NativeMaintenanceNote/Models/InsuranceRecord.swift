//
//  InsuranceRecord.swift
//  NativeMaintenanceNote
//

import Foundation
import SwiftData

@Model
final class InsuranceRecord {
    var id: UUID
    var bike: Bike?
    var type: InsuranceType?
    var name: String
    var price: Int
    var startDate: Date
    var finishDate: Date
    var url: String
    var imageFilenames: [String]
    var memo: String

    init(
        id: UUID = UUID(),
        bike: Bike?,
        type: InsuranceType?,
        name: String,
        price: Int = 0,
        startDate: Date = Date(),
        finishDate: Date = Date(),
        url: String = "",
        imageFilenames: [String] = [],
        memo: String = ""
    ) {
        self.id = id
        self.bike = bike
        self.type = type
        self.name = name
        self.price = price
        self.startDate = startDate
        self.finishDate = finishDate
        self.url = url
        self.imageFilenames = imageFilenames
        self.memo = memo
    }
}
