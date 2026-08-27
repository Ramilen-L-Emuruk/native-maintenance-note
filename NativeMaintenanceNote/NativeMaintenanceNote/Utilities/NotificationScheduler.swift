//
//  NotificationScheduler.swift
//  NativeMaintenanceNote
//
//  保険満了・車検満了・整備部品の周期をUNUserNotificationCenterへローカル通知として予約する。
//  再スケジュール時は毎回既存の通知をすべて破棄してから、対象データを走査し直す方式。
//

import Foundation
import SwiftData
import UserNotifications

enum NotificationScheduler {
    private static let leadDaysKey = "notificationLeadDays"
    static let defaultLeadDays = 7
    static let fireHour = 9

    static var leadDays: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: leadDaysKey) as? Int
            return stored ?? defaultLeadDays
        }
        set { UserDefaults.standard.set(newValue, forKey: leadDaysKey) }
    }

    static func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    static func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    /// 既存の予約通知をすべて破棄し、現在のデータから再構築する。
    /// getNotificationSettingsの completion はバックグラウンドキューで呼ばれるため、
    /// SwiftDataのModelContext（メインアクター）へ触れる処理は必ずメインスレッドへ戻す。
    static func rescheduleAll(context: ModelContext) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                    center.removeAllPendingNotificationRequests()
                    return
                }
                let items = buildItems(context: context, leadDays: leadDays)
                center.removeAllPendingNotificationRequests()
                for item in items {
                    center.add(item.makeRequest())
                }
            }
        }
    }

    struct ReminderItem: Equatable {
        let identifier: String
        let title: String
        let body: String
        let fireDate: Date

        func makeRequest() -> UNNotificationRequest {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            var components = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
            components.hour = fireHour
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        }
    }

    /// 満了日/期限日から、リード日数を引いた通知発火日を求める。
    static func fireDate(for dueDate: Date, leadDays: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -leadDays, to: dueDate) ?? dueDate
    }

    /// 整備部品の周期（intervalDays）から次回目安日を求める。最終整備記録がなければ計算不能。
    static func nextMaintenanceDueDate(lastMaintenanceDate: Date, intervalDays: Int, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: .day, value: intervalDays, to: lastMaintenanceDate)
    }

    static func buildItems(context: ModelContext, leadDays: Int, now: Date = Date(), calendar: Calendar = .current) -> [ReminderItem] {
        var items: [ReminderItem] = []

        let insuranceRecords = (try? context.fetch(FetchDescriptor<InsuranceRecord>())) ?? []
        for record in insuranceRecords {
            guard record.type?.notification == true else { continue }
            let fire = fireDate(for: record.finishDate, leadDays: leadDays, calendar: calendar)
            guard fire > now else { continue }
            let bikeName = record.bike?.name ?? ""
            items.append(ReminderItem(
                identifier: "insurance-\(record.id.uuidString)",
                title: "保険の満了が近づいています",
                body: "\(bikeName) \(record.name)（\(dateString(record.finishDate))まで）",
                fireDate: fire
            ))
        }

        let bikes = (try? context.fetch(FetchDescriptor<Bike>())) ?? []
        for bike in bikes {
            guard !bike.archived, bike.inspectionNotification, let expiry = bike.inspectionExpiryDate else { continue }
            let fire = fireDate(for: expiry, leadDays: leadDays, calendar: calendar)
            guard fire > now else { continue }
            items.append(ReminderItem(
                identifier: "inspection-\(bike.id.uuidString)",
                title: "車検満了が近づいています",
                body: "\(bike.name)の車検満了日は\(dateString(expiry))",
                fireDate: fire
            ))
        }

        let parts = (try? context.fetch(FetchDescriptor<MaintenancePart>())) ?? []
        for part in parts {
            guard part.notification, let intervalDays = part.intervalDays else { continue }
            guard let lastRecord = part.records.max(by: { $0.maintenanceDate < $1.maintenanceDate }) else { continue }
            guard let dueDate = nextMaintenanceDueDate(lastMaintenanceDate: lastRecord.maintenanceDate, intervalDays: intervalDays, calendar: calendar) else { continue }
            let fire = fireDate(for: dueDate, leadDays: leadDays, calendar: calendar)
            guard fire > now else { continue }
            let bikeName = lastRecord.bike?.name ?? ""
            items.append(ReminderItem(
                identifier: "maintenancePart-\(part.id.uuidString)",
                title: "整備時期が近づいています",
                body: "\(bikeName) \(part.name)（目安 \(dateString(dueDate))）",
                fireDate: fire
            ))
        }

        return items
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}
