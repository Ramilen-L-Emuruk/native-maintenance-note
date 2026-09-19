//
//  NotificationSchedulerTests.swift
//  NativeMaintenanceNoteTests
//
//  現在時刻に依存すると「実行した日によって通るテスト」になるため、
//  buildItemsへはnowとcalendarを明示的に渡して判定を固定する。
//

import Testing
import Foundation
import SwiftData
@testable import NativeMaintenanceNote

@MainActor
struct NotificationSchedulerTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Maker.self, Shop.self, MaintenanceType.self, MaintenancePart.self,
            InsuranceType.self, Bike.self, MaintenanceRecord.self, InsuranceRecord.self, RefuelRecord.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// テストの基準となる「現在時刻」。2026年9月15日12時。
    private func makeNow() throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 12)))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func dateTime(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
    }

    private func makeReminders(dueDate: Date, leadDays: Int = 7, now: Date) -> [NotificationScheduler.ReminderItem] {
        NotificationScheduler.makeReminders(
            identifierPrefix: "test",
            leadTitle: "近づいています",
            dueTitle: "本日です",
            body: "本文",
            dueDate: dueDate,
            leadDays: leadDays,
            now: now,
            calendar: calendar
        )
    }

    // MARK: - scheduledFireDate

    @Test func scheduledFireDateSubtractsLeadDaysAndRoundsToFireHour() throws {
        let dueDate = try date(2026, 8, 20)
        let fireDate = try #require(NotificationScheduler.scheduledFireDate(for: dueDate, leadDays: 7, calendar: calendar))

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        #expect(components.year == 2026)
        #expect(components.month == 8)
        #expect(components.day == 13)
        #expect(components.hour == NotificationScheduler.fireHour)
        #expect(components.minute == 0)
    }

    // MARK: - nextMaintenanceDueDate

    @Test func nextMaintenanceDueDateAddsIntervalDaysToLastMaintenanceDate() throws {
        let lastDate = try date(2026, 1, 1)
        let dueDate = try #require(NotificationScheduler.nextMaintenanceDueDate(lastMaintenanceDate: lastDate, intervalDays: 180, calendar: calendar))
        let expected = try date(2026, 6, 30)
        #expect(calendar.isDate(dueDate, inSameDayAs: expected))
    }

    // MARK: - makeReminders

    /// ひとつの期限につき、リード日と期限日当日の2件を作る。
    @Test func makeRemindersCreatesLeadAndDueReminders() throws {
        let now = try makeNow()
        let reminders = makeReminders(dueDate: try date(2026, 10, 15), now: now)

        #expect(reminders.count == 2)
        let lead = try #require(reminders.first { $0.identifier == "test-lead" })
        let due = try #require(reminders.first { $0.identifier == "test-due" })
        #expect(lead.fireDate == (try dateTime(2026, 10, 8, NotificationScheduler.fireHour)))
        #expect(due.fireDate == (try dateTime(2026, 10, 15, NotificationScheduler.fireHour)))
        #expect(lead.title == "近づいています")
        #expect(due.title == "本日です")
    }

    /// リード日をすでに過ぎている場合は、期限日当日のぶんだけが残る。
    /// ここで通知を捨てると「最も差し迫った期限ほど通知されない」ことになる。
    @Test func makeRemindersKeepsOnlyDueReminderWhenLeadDatePassed() throws {
        let now = try makeNow()
        let reminders = makeReminders(dueDate: try date(2026, 9, 18), now: now)

        #expect(reminders.count == 1)
        #expect(reminders.first?.identifier == "test-due")
        #expect(reminders.first?.fireDate == (try dateTime(2026, 9, 18, NotificationScheduler.fireHour)))
    }

    /// 期限日当日でも、その日の通知時刻より前なら当日ぶんは残る。
    @Test func makeRemindersKeepsDueReminderBeforeFireHourOnDueDate() throws {
        let now = try dateTime(2026, 9, 16, NotificationScheduler.fireHour - 1)
        let reminders = makeReminders(dueDate: try date(2026, 9, 16), now: now)

        #expect(reminders.count == 1)
        #expect(reminders.first?.fireDate == (try dateTime(2026, 9, 16, NotificationScheduler.fireHour)))
    }

    @Test func makeRemindersReturnsEmptyWhenDueDateFireHourPassed() throws {
        let now = try dateTime(2026, 9, 16, NotificationScheduler.fireHour + 1)
        #expect(makeReminders(dueDate: try date(2026, 9, 16), now: now).isEmpty)
    }

    @Test func makeRemindersReturnsEmptyWhenDueDateAlreadyPast() throws {
        let now = try makeNow()
        #expect(makeReminders(dueDate: try date(2026, 9, 10), now: now).isEmpty)
    }

    /// leadDaysが0だと2件が同じ日時になってしまうため、期限日当日のぶんだけにする。
    @Test func makeRemindersSkipsLeadReminderWhenLeadDaysIsZero() throws {
        let now = try makeNow()
        let reminders = makeReminders(dueDate: try date(2026, 10, 15), leadDays: 0, now: now)

        #expect(reminders.count == 1)
        #expect(reminders.first?.identifier == "test-due")
    }

    /// 再構築は前面復帰のたびに走る。配信日時がnowに依存すると、期限までアプリを開くたびに
    /// 新しい日時で予約し直され、届く回数が「アプリを開いたかどうか」で変わってしまう。
    /// dueDateとleadDaysだけから決まっていれば、いつ組み直しても同じ日時に収束する。
    @Test func makeRemindersStayStableAcrossRepeatedRebuilds() throws {
        let dueDate = try date(2026, 12, 1)
        let expectedLead = try dateTime(2026, 11, 24, NotificationScheduler.fireHour)
        let expectedDue = try dateTime(2026, 12, 1, NotificationScheduler.fireHour)

        // リード日より前は、2件とも同じ日時で安定する。
        for day in 20...23 {
            let reminders = makeReminders(dueDate: dueDate, now: try dateTime(2026, 11, day, 12))
            #expect(reminders.map(\.fireDate) == [expectedLead, expectedDue])
        }

        // リード日当日は通知時刻をまたいで内容が変わる。前後どちらも確かめる。
        let beforeFireHour = makeReminders(dueDate: dueDate, now: try dateTime(2026, 11, 24, NotificationScheduler.fireHour - 1))
        #expect(beforeFireHour.map(\.fireDate) == [expectedLead, expectedDue])
        let afterFireHour = makeReminders(dueDate: dueDate, now: try dateTime(2026, 11, 24, NotificationScheduler.fireHour + 1))
        #expect(afterFireHour.map(\.fireDate) == [expectedDue])

        // リード日を過ぎた後は、期限日当日のぶんが同じ日時で安定する。
        for day in 25...30 {
            let reminders = makeReminders(dueDate: dueDate, now: try dateTime(2026, 11, day, 12))
            #expect(reminders.map(\.fireDate) == [expectedDue])
        }
    }

    // MARK: - buildItems: 保険満了

    @Test func buildItemsIncludesInsuranceRecordWhenTypeNotificationEnabled() throws {
        let context = try makeContext()
        let now = try makeNow()
        let bike = Bike(maker: nil, name: "Shadow")
        let type = InsuranceType(name: "自賠責", notification: true)
        let record = InsuranceRecord(bike: bike, type: type, name: "自賠責保険", finishDate: try date(2026, 12, 1))
        context.insert(bike)
        context.insert(type)
        context.insert(record)

        let items = try NotificationScheduler.buildItems(context: context, leadDays: 7, now: now, calendar: calendar)

        #expect(items.filter { $0.identifier.hasPrefix("insurance-\(record.id.uuidString)") }.count == 2)
    }

    @Test func buildItemsExcludesInsuranceRecordWhenTypeNotificationDisabled() throws {
        let context = try makeContext()
        let now = try makeNow()
        let bike = Bike(maker: nil, name: "Shadow")
        let type = InsuranceType(name: "自賠責", notification: false)
        let record = InsuranceRecord(bike: bike, type: type, name: "自賠責保険", finishDate: try date(2026, 12, 1))
        context.insert(bike)
        context.insert(type)
        context.insert(record)

        let items = try NotificationScheduler.buildItems(context: context, leadDays: 7, now: now, calendar: calendar)

        #expect(!items.contains { $0.identifier.hasPrefix("insurance-\(record.id.uuidString)") })
    }

    /// 満了が迫っていてリード日を過ぎていても、期限日当日のぶんは作られる。
    @Test func buildItemsIncludesInsuranceRecordWhenLeadWindowPassed() throws {
        let context = try makeContext()
        let now = try makeNow()
        let bike = Bike(maker: nil, name: "Shadow")
        let type = InsuranceType(name: "自賠責", notification: true)
        let record = InsuranceRecord(bike: bike, type: type, name: "自賠責保険", finishDate: try date(2026, 9, 16))
        context.insert(bike)
        context.insert(type)
        context.insert(record)

        let items = try NotificationScheduler.buildItems(context: context, leadDays: 7, now: now, calendar: calendar)

        let matched = items.filter { $0.identifier.hasPrefix("insurance-\(record.id.uuidString)") }
        #expect(matched.count == 1)
        #expect(matched.first?.identifier.hasSuffix("-due") == true)
    }

    @Test func buildItemsExcludesInsuranceRecordWhenDueDateAlreadyPast() throws {
        let context = try makeContext()
        let now = try makeNow()
        let bike = Bike(maker: nil, name: "Shadow")
        let type = InsuranceType(name: "自賠責", notification: true)
        let record = InsuranceRecord(bike: bike, type: type, name: "自賠責保険", finishDate: try date(2026, 9, 1))
        context.insert(bike)
        context.insert(type)
        context.insert(record)

        let items = try NotificationScheduler.buildItems(context: context, leadDays: 7, now: now, calendar: calendar)

        #expect(!items.contains { $0.identifier.hasPrefix("insurance-\(record.id.uuidString)") })
    }

    @Test func buildItemsExcludesInsuranceRecordOfArchivedBike() throws {
        let context = try makeContext()
        let now = try makeNow()
        let bike = Bike(maker: nil, name: "Shadow", archived: true)
        let type = InsuranceType(name: "自賠責", notification: true)
        let record = InsuranceRecord(bike: bike, type: type, name: "自賠責保険", finishDate: try date(2026, 12, 1))
        context.insert(bike)
        context.insert(type)
        context.insert(record)

        let items = try NotificationScheduler.buildItems(context: context, leadDays: 7, now: now, calendar: calendar)

        #expect(!items.contains { $0.identifier.hasPrefix("insurance-\(record.id.uuidString)") })
    }

    // MARK: - buildItems: 車検満了

    @Test func buildItemsIncludesBikeInspectionWhenEnabled() throws {
        let context = try makeContext()
        let now = try makeNow()
        let bike = Bike(maker: nil, name: "Shadow", inspectionExpiryDate: try date(2026, 12, 1), inspectionNotification: true)
        context.insert(bike)

        let items = try NotificationScheduler.buildItems(context: context, leadDays: 7, now: now, calendar: calendar)

        #expect(items.filter { $0.identifier.hasPrefix("inspection-\(bike.id.uuidString)") }.count == 2)
    }

    @Test func buildItemsExcludesArchivedBikeInspection() throws {
        let context = try makeContext()
        let now = try makeNow()
        let bike = Bike(maker: nil, name: "Shadow", inspectionExpiryDate: try date(2026, 12, 1), inspectionNotification: true, archived: true)
        context.insert(bike)

        let items = try NotificationScheduler.buildItems(context: context, leadDays: 7, now: now, calendar: calendar)

        #expect(!items.contains { $0.identifier.hasPrefix("inspection-\(bike.id.uuidString)") })
    }

    // MARK: - buildItems: 整備部品

    @Test func buildItemsIncludesMaintenancePartUsingLatestRecordDate() throws {
        let context = try makeContext()
        let now = try makeNow()
        let bike = Bike(maker: nil, name: "Shadow")
        let type = MaintenanceType(name: "エンジンオイル")
        let part = MaintenancePart(type: type, name: "オイル交換", intervalDays: 180, notification: true)
        let oldRecord = MaintenanceRecord(bike: bike, part: part, title: "交換", maintenanceDate: try date(2026, 2, 1))
        let latestRecord = MaintenanceRecord(bike: bike, part: part, title: "交換", maintenanceDate: try date(2026, 9, 5))
        context.insert(bike)
        context.insert(type)
        context.insert(part)
        context.insert(oldRecord)
        context.insert(latestRecord)

        let items = try NotificationScheduler.buildItems(context: context, leadDays: 7, now: now, calendar: calendar)

        // 直近整備日(2026-09-05) + 180日 = 2027-03-04 が目安日になる。
        let matched = items.filter { $0.identifier.hasPrefix("maintenancePart-\(part.id.uuidString)-\(bike.id.uuidString)") }
        #expect(matched.count == 2)
        #expect(matched.allSatisfy { $0.body.contains("2027") })
    }

    /// MaintenancePartはバイクを持たない共有カタログで、複数のバイクが同じ部品を参照する。
    /// 全記録から最新1件だけを採ると、直近に整備していないバイクの通知が消える。
    @Test func buildItemsCreatesItemPerBikeForSharedMaintenancePart() throws {
        let context = try makeContext()
        let now = try makeNow()
        let type = MaintenanceType(name: "エンジンオイル")
        let part = MaintenancePart(type: type, name: "オイル交換", intervalDays: 180, notification: true)
        let shadow = Bike(maker: nil, name: "Shadow")
        let monkey = Bike(maker: nil, name: "Monkey")
        let shadowRecord = MaintenanceRecord(bike: shadow, part: part, title: "交換", maintenanceDate: try date(2026, 9, 1))
        let monkeyRecord = MaintenanceRecord(bike: monkey, part: part, title: "交換", maintenanceDate: try date(2026, 5, 1))
        context.insert(type)
        context.insert(part)
        context.insert(shadow)
        context.insert(monkey)
        context.insert(shadowRecord)
        context.insert(monkeyRecord)

        let items = try NotificationScheduler.buildItems(context: context, leadDays: 7, now: now, calendar: calendar)

        let shadowItems = items.filter { $0.identifier.hasPrefix("maintenancePart-\(part.id.uuidString)-\(shadow.id.uuidString)") }
        let monkeyItems = items.filter { $0.identifier.hasPrefix("maintenancePart-\(part.id.uuidString)-\(monkey.id.uuidString)") }
        #expect(shadowItems.count == 2)
        #expect(monkeyItems.count == 2)
        #expect(shadowItems.allSatisfy { $0.body.contains("Shadow") })
        #expect(monkeyItems.allSatisfy { $0.body.contains("Monkey") })
        #expect(shadowItems.map(\.fireDate) != monkeyItems.map(\.fireDate))
    }

    @Test func buildItemsExcludesMaintenancePartOfArchivedBike() throws {
        let context = try makeContext()
        let now = try makeNow()
        let type = MaintenanceType(name: "エンジンオイル")
        let part = MaintenancePart(type: type, name: "オイル交換", intervalDays: 180, notification: true)
        let bike = Bike(maker: nil, name: "Shadow", archived: true)
        let record = MaintenanceRecord(bike: bike, part: part, title: "交換", maintenanceDate: try date(2026, 9, 1))
        context.insert(type)
        context.insert(part)
        context.insert(bike)
        context.insert(record)

        let items = try NotificationScheduler.buildItems(context: context, leadDays: 7, now: now, calendar: calendar)

        #expect(!items.contains { $0.identifier.hasPrefix("maintenancePart-\(part.id.uuidString)") })
    }

    @Test func buildItemsExcludesMaintenancePartWithoutRecords() throws {
        let context = try makeContext()
        let now = try makeNow()
        let type = MaintenanceType(name: "エンジンオイル")
        let part = MaintenancePart(type: type, name: "オイル交換", intervalDays: 180, notification: true)
        context.insert(type)
        context.insert(part)

        let items = try NotificationScheduler.buildItems(context: context, leadDays: 7, now: now, calendar: calendar)

        #expect(!items.contains { $0.identifier.hasPrefix("maintenancePart-\(part.id.uuidString)") })
    }

    /// 走行距離のみで管理している部品は通知の対象外（ローカル通知は日時でしか予約できないため）。
    @Test func buildItemsExcludesMaintenancePartWithoutIntervalDays() throws {
        let context = try makeContext()
        let now = try makeNow()
        let bike = Bike(maker: nil, name: "Shadow")
        let type = MaintenanceType(name: "タイヤ")
        let part = MaintenancePart(type: type, name: "フロント", intervalDays: nil, intervalDistance: 15000, notification: true)
        let record = MaintenanceRecord(bike: bike, part: part, title: "交換", maintenanceDate: try date(2026, 9, 1))
        context.insert(bike)
        context.insert(type)
        context.insert(part)
        context.insert(record)

        let items = try NotificationScheduler.buildItems(context: context, leadDays: 7, now: now, calendar: calendar)

        #expect(!items.contains { $0.identifier.hasPrefix("maintenancePart-\(part.id.uuidString)") })
    }

    // MARK: - 保留通知の上限

    /// iOSが受け付ける保留通知には上限がある。超過分をOS任せに落とすと、
    /// どの通知が生き残るかを制御できないため、配信日の近い順に残す。
    @Test func buildItemsKeepsNearestItemsWithinPendingLimit() throws {
        let context = try makeContext()
        let now = try makeNow()
        let type = InsuranceType(name: "任意保険", notification: true)
        context.insert(type)

        // 1レコードにつき2件（リード日・期限日当日）作られるため、上限の半分を超える数を用意する。
        let recordCount = NotificationScheduler.maxPendingRequests
        var farthestPrefix = ""
        for index in 0..<recordCount {
            let bike = Bike(maker: nil, name: "Bike\(index)")
            // 満了日を1日ずつ後ろへずらし、最後に作ったものが最も遠い期限になるようにする。
            let finishDate = try #require(calendar.date(byAdding: .day, value: 30 + index, to: now))
            let record = InsuranceRecord(bike: bike, type: type, name: "任意保険\(index)", finishDate: finishDate)
            context.insert(bike)
            context.insert(record)
            farthestPrefix = "insurance-\(record.id.uuidString)"
        }

        let items = try NotificationScheduler.buildItems(context: context, leadDays: 7, now: now, calendar: calendar)

        #expect(items.count == NotificationScheduler.maxPendingRequests)
        #expect(!items.contains { $0.identifier.hasPrefix(farthestPrefix) })
        // 配信日の昇順に並んでいること（切り詰めの基準が保たれていること）。
        #expect(items.map(\.fireDate) == items.map(\.fireDate).sorted())
    }
}
