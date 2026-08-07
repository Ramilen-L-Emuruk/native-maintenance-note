//
//  Bike.swift
//  NativeMaintenanceNote
//

import Foundation
import SwiftData

@Model
final class Bike {
    var id: UUID
    var maker: Maker?
    var name: String
    var frameNumber: String
    var nickname: String
    var displacement: Int
    var purchaseShop: Shop?
    var purchaseDate: Date?
    var mileageAtRegistration: Int
    var totalMileage: Int
    var imageFilenames: [String]
    var inspectionExpiryDate: Date?
    var memo: String
    var archived: Bool

    @Relationship(deleteRule: .cascade, inverse: \MaintenanceRecord.bike)
    var maintenanceRecords: [MaintenanceRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \InsuranceRecord.bike)
    var insuranceRecords: [InsuranceRecord] = []

    init(
        id: UUID = UUID(),
        maker: Maker?,
        name: String,
        frameNumber: String = "",
        nickname: String = "",
        displacement: Int = 0,
        purchaseShop: Shop? = nil,
        purchaseDate: Date? = nil,
        mileageAtRegistration: Int = 0,
        totalMileage: Int = 0,
        imageFilenames: [String] = [],
        inspectionExpiryDate: Date? = nil,
        memo: String = "",
        archived: Bool = false
    ) {
        self.id = id
        self.maker = maker
        self.name = name
        self.frameNumber = frameNumber
        self.nickname = nickname
        self.displacement = displacement
        self.purchaseShop = purchaseShop
        self.purchaseDate = purchaseDate
        self.mileageAtRegistration = mileageAtRegistration
        self.totalMileage = totalMileage
        self.imageFilenames = imageFilenames
        self.inspectionExpiryDate = inspectionExpiryDate
        self.memo = memo
        self.archived = archived
    }
}
