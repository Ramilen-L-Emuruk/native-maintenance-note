//
//  RefuelRecord.swift
//  NativeMaintenanceNote
//
//  Web版ではrefuelDateとrefuelTimeを分けて持っていたが、
//  SwiftUI/SwiftDataでは単一のDateに統合する設計判断(docs参照)。
//

import Foundation
import SwiftData

@Model
final class RefuelRecord {
    var id: UUID
    var bike: Bike?
    var refuelDate: Date
    var previousMileage: Int
    var totalMileage: Int
    var price: Int
    var refuelAmount: Double
    var memo: String
    var isFullTank: Bool
    var includeInFuelEconomy: Bool

    init(
        id: UUID = UUID(),
        bike: Bike?,
        refuelDate: Date = Date(),
        previousMileage: Int = 0,
        totalMileage: Int = 0,
        price: Int = 0,
        refuelAmount: Double = 0,
        memo: String = "",
        isFullTank: Bool = true,
        includeInFuelEconomy: Bool = true
    ) {
        self.id = id
        self.bike = bike
        self.refuelDate = refuelDate
        self.previousMileage = previousMileage
        self.totalMileage = totalMileage
        self.price = price
        self.refuelAmount = refuelAmount
        self.memo = memo
        self.isFullTank = isFullTank
        self.includeInFuelEconomy = includeInFuelEconomy
    }
}
