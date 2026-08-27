//
//  NotificationSchedulerTests.swift
//  NativeMaintenanceNoteTests
//

import Testing
import Foundation
import SwiftData
@testable import NativeMaintenanceNote

struct NotificationSchedulerTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Maker.self, Shop.self, MaintenanceType.self, MaintenancePart.self,
            InsuranceType.self, Bike.self, MaintenanceRecord.self, InsuranceRecord.self, RefuelRecord.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - fireDate

    @Test func fireDateSubtractsLeadDaysFromDueDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let dueDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 20)))
        let fireDate = NotificationScheduler.fireDate(for: dueDate, leadDays: 7, calendar: calendar)
        let expected = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 13)))
        #expect(calendar.isDate(fireDate, inSameDayAs: expected))
    }

    // MARK: - nextMaintenanceDueDate

    @Test func nextMaintenanceDueDateAddsIntervalDaysToLastMaintenanceDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let lastDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let dueDate = try #require(NotificationScheduler.nextMaintenanceDueDate(lastMaintenanceDate: lastDate, intervalDays: 180, calendar: calendar))
        let expected = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 30)))
        #expect(calendar.isDate(dueDate, inSameDayAs: expected))
    }

    // MARK: - buildItems: 保険満了

    @Test func buildItemsIncludesInsuranceRecordWhenTypeNotificationEnabled() throws {
        let context = try makeContext()
        let bike = Bike(maker: nil, name: "Shadow")
        let type = InsuranceType(name: "自賠責", notification: true)
        let farFuture = Date().addingTimeInterval(60 * 24 * 60 * 60)
        let record = InsuranceRecord(bike: bike, type: type, name: "自賠責保険", finishDate: farFuture)
        context.insert(bike)
        context.insert(type)
        context.insert(record)

        let items = NotificationScheduler.buildItems(context: context, leadDays: 7)

        #expect(items.contains { $0.identifier == "insurance-\(record.id.uuidString)" })
    }

    @Test func buildItemsExcludesInsuranceRecordWhenTypeNotificationDisabled() throws {
        let context = try makeContext()
        let bike = Bike(maker: nil, name: "Shadow")
        let type = InsuranceType(name: "自賠責", notification: false)
        let farFuture = Date().addingTimeInterval(60 * 24 * 60 * 60)
        let record = InsuranceRecord(bike: bike, type: type, name: "自賠責保険", finishDate: farFuture)
        context.insert(bike)
        context.insert(type)
        context.insert(record)

        let items = NotificationScheduler.buildItems(context: context, leadDays: 7)

        #expect(!items.contains { $0.identifier == "insurance-\(record.id.uuidString)" })
    }

    @Test func buildItemsExcludesInsuranceRecordWhenFireDateAlreadyPast() throws {
        let context = try makeContext()
        let bike = Bike(maker: nil, name: "Shadow")
        let type = InsuranceType(name: "自賠責", notification: true)
        // 満了日が明日 → リード7日前はすでに過去
        let nearFuture = Date().addingTimeInterval(1 * 24 * 60 * 60)
        let record = InsuranceRecord(bike: bike, type: type, name: "自賠責保険", finishDate: nearFuture)
        context.insert(bike)
        context.insert(type)
        context.insert(record)

        let items = NotificationScheduler.buildItems(context: context, leadDays: 7)

        #expect(!items.contains { $0.identifier == "insurance-\(record.id.uuidString)" })
    }

    // MARK: - buildItems: 車検満了

    @Test func buildItemsIncludesBikeInspectionWhenEnabled() throws {
        let context = try makeContext()
        let farFuture = Date().addingTimeInterval(60 * 24 * 60 * 60)
        let bike = Bike(maker: nil, name: "Shadow", inspectionExpiryDate: farFuture, inspectionNotification: true)
        context.insert(bike)

        let items = NotificationScheduler.buildItems(context: context, leadDays: 7)

        #expect(items.contains { $0.identifier == "inspection-\(bike.id.uuidString)" })
    }

    @Test func buildItemsExcludesArchivedBikeInspection() throws {
        let context = try makeContext()
        let farFuture = Date().addingTimeInterval(60 * 24 * 60 * 60)
        let bike = Bike(maker: nil, name: "Shadow", inspectionExpiryDate: farFuture, inspectionNotification: true, archived: true)
        context.insert(bike)

        let items = NotificationScheduler.buildItems(context: context, leadDays: 7)

        #expect(!items.contains { $0.identifier == "inspection-\(bike.id.uuidString)" })
    }

    // MARK: - buildItems: 整備部品

    @Test func buildItemsIncludesMaintenancePartUsingLatestRecordDate() throws {
        let context = try makeContext()
        let bike = Bike(maker: nil, name: "Shadow")
        let type = MaintenanceType(name: "エンジンオイル")
        let part = MaintenancePart(type: type, name: "オイル交換", intervalDays: 180, notification: true)
        let oldRecord = MaintenanceRecord(bike: bike, part: part, title: "交換", maintenanceDate: Date().addingTimeInterval(-200 * 24 * 60 * 60))
        let latestRecord = MaintenanceRecord(bike: bike, part: part, title: "交換", maintenanceDate: Date().addingTimeInterval(-10 * 24 * 60 * 60))
        context.insert(bike)
        context.insert(type)
        context.insert(part)
        context.insert(oldRecord)
        context.insert(latestRecord)

        // 次回目安 = 直近整備日(10日前) + 180日 → 十分未来なのでリード7日分を引いても未来
        let items = NotificationScheduler.buildItems(context: context, leadDays: 7)

        #expect(items.contains { $0.identifier == "maintenancePart-\(part.id.uuidString)" })
    }

    @Test func buildItemsExcludesMaintenancePartWithoutRecords() throws {
        let context = try makeContext()
        let type = MaintenanceType(name: "エンジンオイル")
        let part = MaintenancePart(type: type, name: "オイル交換", intervalDays: 180, notification: true)
        context.insert(type)
        context.insert(part)

        let items = NotificationScheduler.buildItems(context: context, leadDays: 7)

        #expect(!items.contains { $0.identifier == "maintenancePart-\(part.id.uuidString)" })
    }

    @Test func buildItemsExcludesMaintenancePartWithoutIntervalDays() throws {
        let context = try makeContext()
        let bike = Bike(maker: nil, name: "Shadow")
        let type = MaintenanceType(name: "エンジンオイル")
        let part = MaintenancePart(type: type, name: "オイル交換", intervalDays: nil, notification: true)
        let record = MaintenanceRecord(bike: bike, part: part, title: "交換", maintenanceDate: Date())
        context.insert(bike)
        context.insert(type)
        context.insert(part)
        context.insert(record)

        let items = NotificationScheduler.buildItems(context: context, leadDays: 7)

        #expect(!items.contains { $0.identifier == "maintenancePart-\(part.id.uuidString)" })
    }
}
