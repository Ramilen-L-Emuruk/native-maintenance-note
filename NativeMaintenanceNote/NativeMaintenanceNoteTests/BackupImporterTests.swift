//
//  BackupImporterTests.swift
//  NativeMaintenanceNoteTests
//

import Testing
import Foundation
import SwiftData
@testable import NativeMaintenanceNote

@MainActor
struct BackupImporterTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Maker.self, Shop.self, MaintenanceType.self, MaintenancePart.self,
            InsuranceType.self, Bike.self, MaintenanceRecord.self, InsuranceRecord.self, RefuelRecord.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func minimalDTO(makers: [MakerDTO] = [], bikes: [BikeDTO] = []) -> BackupDTO {
        BackupDTO(
            app: "web-maintenance-note",
            version: 1,
            makers: makers,
            shops: [],
            bikes: bikes,
            maintenanceTypes: [],
            maintenanceParts: [],
            maintenanceRecords: [],
            insuranceTypes: [],
            insuranceRecords: [],
            refuelRecords: []
        )
    }

    @Test func decodeRejectsFileWithWrongAppField() throws {
        let json = """
        {"app":"something-else","version":1,"makers":[],"shops":[],"bikes":[],"maintenanceTypes":[],"maintenanceParts":[],"maintenanceRecords":[],"insuranceTypes":[],"insuranceRecords":[],"refuelRecords":[]}
        """.data(using: .utf8)!

        #expect(throws: BackupImportError.self) {
            try BackupImporter.decode(json)
        }
    }

    @Test func decodeAcceptsValidBackup() throws {
        let json = """
        {"app":"web-maintenance-note","version":1,"makers":[],"shops":[],"bikes":[],"maintenanceTypes":[],"maintenanceParts":[],"maintenanceRecords":[],"insuranceTypes":[],"insuranceRecords":[],"refuelRecords":[]}
        """.data(using: .utf8)!

        let dto = try BackupImporter.decode(json)
        #expect(dto.app == "web-maintenance-note")
    }

    @Test func parseDateParsesISODateString() throws {
        let date = BackupImporter.parseDate("2026-08-08")
        let components = Calendar.current.dateComponents([.year, .month, .day], from: try #require(date))
        #expect(components.year == 2026)
        #expect(components.month == 8)
        #expect(components.day == 8)
    }

    @Test func combinedDateMergesDateAndTime() throws {
        let date = try #require(BackupImporter.combinedDate(dateString: "2026-08-08", timeString: "16:05"))
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        #expect(components.year == 2026)
        #expect(components.month == 8)
        #expect(components.day == 8)
        #expect(components.hour == 16)
        #expect(components.minute == 5)
    }

    @Test func executeMatchesExistingMasterDataByNameInsteadOfDuplicating() throws {
        let context = try makeContext()
        context.insert(Maker(name: "Honda", isSeeded: true))

        let dto = minimalDTO(
            makers: [MakerDTO(id: "web-honda", name: "Honda")],
            bikes: [BikeDTO(
                id: "web-bike-1", makerId: "web-honda", name: "Shadow", frameNumber: "", nickname: "",
                displacement: 1100, purchaseShopId: nil, purchaseDate: nil, mileageAtRegistration: 0,
                totalMileage: 1000, images: [], inspectionExpiryDate: nil, memo: "", archived: false
            )]
        )

        BackupImporter.execute(dto, context: context)

        let makers = try context.fetch(FetchDescriptor<Maker>())
        #expect(makers.count == 1)

        let bikes = try context.fetch(FetchDescriptor<Bike>())
        #expect(bikes.count == 1)
        #expect(bikes.first?.maker?.name == "Honda")
    }

    @Test func executeCreatesNewMasterDataWhenNameNotFound() throws {
        let context = try makeContext()

        let dto = minimalDTO(makers: [MakerDTO(id: "web-ducati", name: "Ducati")])

        BackupImporter.execute(dto, context: context)

        let makers = try context.fetch(FetchDescriptor<Maker>())
        #expect(makers.count == 1)
        #expect(makers.first?.name == "Ducati")
        #expect(makers.first?.isSeeded == false)
    }

    @Test func previewListsOnlyNamesNotAlreadyPresent() throws {
        let context = try makeContext()
        context.insert(Maker(name: "Honda", isSeeded: true))

        let dto = minimalDTO(makers: [
            MakerDTO(id: "web-honda", name: "Honda"),
            MakerDTO(id: "web-ducati", name: "Ducati"),
        ])

        let preview = BackupImporter.preview(dto, context: context)

        #expect(preview.newMakerNames == ["Ducati"])
    }
}
