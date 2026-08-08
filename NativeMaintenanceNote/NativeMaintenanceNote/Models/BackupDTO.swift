//
//  BackupDTO.swift
//  NativeMaintenanceNote
//
//  Web版(web-maintenance-note)のバックアップJSON形状をそのままミラーするDTO。
//  IDは文字列UUID、日付はISO文字列(YYYY-MM-DD)のまま保持し、
//  SwiftDataモデルへの変換はBackupImporterが担う。
//

import Foundation

struct BackupDTO: Codable {
    let app: String
    let version: Int
    let makers: [MakerDTO]
    let shops: [ShopDTO]
    let bikes: [BikeDTO]
    let maintenanceTypes: [MaintenanceTypeDTO]
    let maintenanceParts: [MaintenancePartDTO]
    let maintenanceRecords: [MaintenanceRecordDTO]
    let insuranceTypes: [InsuranceTypeDTO]
    let insuranceRecords: [InsuranceRecordDTO]
    let refuelRecords: [RefuelRecordDTO]
}

struct MakerDTO: Codable {
    let id: String
    let name: String
}

struct ShopDTO: Codable {
    let id: String
    let name: String
    let address: String
}

struct BikeDTO: Codable {
    let id: String
    let makerId: String
    let name: String
    let frameNumber: String
    let nickname: String
    let displacement: Int
    let purchaseShopId: String?
    let purchaseDate: String?
    let mileageAtRegistration: Int
    let totalMileage: Int
    let images: [String]
    let inspectionExpiryDate: String?
    let memo: String
    let archived: Bool
}

struct MaintenanceTypeDTO: Codable {
    let id: String
    let name: String
}

struct MaintenancePartDTO: Codable {
    let id: String
    let maintenanceTypeId: String
    let name: String
    let intervalDays: Int?
    let intervalDistance: Int?
    let notification: Bool
}

struct MaintenanceRecordDTO: Codable {
    let id: String
    let bikeId: String
    let maintenancePartId: String
    let title: String
    let maintenanceDate: String
    let price: Int
    let mileage: Int?
    let images: [String]
    let memo: String
}

struct InsuranceTypeDTO: Codable {
    let id: String
    let name: String
    let notification: Bool
}

struct InsuranceRecordDTO: Codable {
    let id: String
    let bikeId: String
    let insuranceTypeId: String
    let name: String
    let price: Int
    let startDate: String
    let finishDate: String
    let url: String
    let images: [String]
    let memo: String
}

struct RefuelRecordDTO: Codable {
    let id: String
    let bikeId: String
    let refuelDate: String
    let refuelTime: String?
    let previousMileage: Int
    let totalMileage: Int
    let price: Int
    let refuelAmount: Double
    let memo: String
    let isFullTank: Bool
    let includeInFuelEconomy: Bool
}
