//
//  NotificationScheduler.swift
//  NativeMaintenanceNote
//
//  保険満了・車検満了・整備部品の周期をUNUserNotificationCenterへローカル通知として予約する。
//  再スケジュール時は毎回既存の通知をすべて破棄してから、対象データを走査し直す方式。
//  ただしデータの取得に失敗した場合は破棄も走査も行わず、既存の予約をそのまま残す。
//
//  ひとつの期限につき、リード日と期限日当日の2回ぶんを予約する。
//
//  配信日時は必ず「絶対日時」で決める。現在時刻からの相対指定(UNTimeIntervalNotificationTrigger)も、
//  「現在時刻の直後の通知時刻」のような算出も使わない。再構築は前面復帰のたびに走るため、
//  nowに依存させると組み直すたびに配信予定がずれ、届く回数も「アプリを開いたかどうか」で変わる。
//
//  走行距離ベースの周期(MaintenancePart.intervalDistance)は対象外。ローカル通知は日時でしか
//  予約できず、走行距離の到達を日時へ変換できないため、別の仕組みが必要になる。
//

import Foundation
import OSLog
import SwiftData
import UserNotifications

enum NotificationScheduler {
    nonisolated private static let logger = Logger(subsystem: "com.ramilen.NativeMaintenanceNote", category: "NotificationScheduler")

    private static let leadDaysKey = "notificationLeadDays"
    nonisolated static let defaultLeadDays = 7
    /// 通知を配信する時刻（時）。分は0に固定する。
    nonisolated static let fireHour = 9
    /// iOSが1アプリあたりに保持する保留中ローカル通知の上限。これを超える分はOSが受け付けない。
    nonisolated static let maxPendingRequests = 64

    static var leadDays: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: leadDaysKey) as? Int
            return stored ?? defaultLeadDays
        }
        set { UserDefaults.standard.set(newValue, forKey: leadDaysKey) }
    }

    /// 通知の許可を求め、許可されたかを返す。
    @MainActor
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("通知の許可要求に失敗: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    @MainActor
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 既存の予約通知をすべて破棄し、現在のデータから再構築する。
    ///
    /// 呼び出し側を同期のままにするためTaskで包む。中身はMainActor上で動くので、
    /// SwiftDataのModelContext（Sendableではない）へそのまま触れる。
    ///
    /// 短い間隔で複数回呼ばれても、破棄と発行の一連が中断しないため
    /// 最後の呼び出しの内容に収束する（理由は publish の実装コメント）。
    @MainActor
    static func rescheduleAll(context: ModelContext) {
        Task { await rescheduleAllAsync(context: context) }
    }

    @MainActor
    private static func rescheduleAllAsync(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else {
            logger.notice("通知が許可されていないため、予約済みの通知をすべて取り消した")
            center.removeAllPendingNotificationRequests()
            return
        }
        let items: [ReminderItem]
        do {
            items = try buildItems(context: context, leadDays: leadDays)
        } catch {
            // 取得に失敗した状態で組み直すと、正しく予約できていた他の種別まで巻き添えで消える。
            // 既存の予約を残したまま今回の再構築を見送り、次の機会に作り直す。
            //
            // この中断経路は自動テストで検証できていない。ModelContextのfetchを
            // 意図的に失敗させる手段がなく、検証にはUNUserNotificationCenterの抽象化が要るため。
            // ここを触るときは手動で確かめること。
            logger.error("通知の再構築を中止し、既存の予約を維持した: \(error.localizedDescription, privacy: .public)")
            return
        }
        publish(items, to: center)
    }

    /// 予約済みの通知をすべて破棄し、itemsを発行する。
    ///
    /// **この関数をasyncにしてはいけない。** 破棄と発行の間で実行権を手放すと、
    /// その隙に別の再構築が割り込んで removeAll を呼び、双方のitemsが混ざった状態が残る
    /// （@MainActorでもサスペンド中は実行権を手放すため）。
    /// 同期のまま一連を終えることで、短い間隔で複数回呼ばれても最後の内容に収束する。
    /// addにcompletion handler版を使っているのはそのため。
    ///
    /// **addのcompletionはSwift 6のSendableチェックの対象外。** UNUserNotificationCenterの
    /// ObjC APIに並行性の注釈がないため、コンパイラは判定していない（警告が出ないことは
    /// 安全の証明にならない）。しかも呼ばれるスレッドは保証されていない。
    /// ここで捕捉してよいのは値型・Sendableなものだけ——MainActor専有の可変状態を
    /// 触るコードを足さないこと。
    @MainActor
    private static func publish(_ items: [ReminderItem], to center: UNUserNotificationCenter) {
        center.removeAllPendingNotificationRequests()
        for item in items {
            center.add(item.makeRequest()) { error in
                if let error {
                    logger.error("通知の予約に失敗(\(item.identifier, privacy: .public)): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    nonisolated struct ReminderItem: Equatable {
        let identifier: String
        let title: String
        let body: String
        /// 通知を配信する日時。fireHourへ丸めた絶対日時。
        let fireDate: Date

        func makeRequest() -> UNNotificationRequest {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            // fireDateは既にfireHourへ丸めてあるため、時・分も含めてそのまま指定する。
            // 年月日だけを指定して時刻を後から上書きすると、判定に使った日時と実際の予約日時がずれる。
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        }
    }

    /// 満了日/期限日からリード日数を引き、通知時刻（fireHour時00分）へ丸めた日時を返す。
    nonisolated static func scheduledFireDate(for dueDate: Date, leadDays: Int, calendar: Calendar = .current) -> Date? {
        guard let leadDate = calendar.date(byAdding: .day, value: -leadDays, to: dueDate) else {
            logger.error("通知予定日の算出に失敗: leadDays=\(leadDays)")
            return nil
        }
        var components = calendar.dateComponents([.year, .month, .day], from: leadDate)
        components.hour = fireHour
        components.minute = 0
        guard let fireDate = calendar.date(from: components) else {
            logger.error("通知予定日の時刻丸めに失敗: leadDays=\(leadDays)")
            return nil
        }
        return fireDate
    }

    /// 整備部品の周期（intervalDays）から次回目安日を求める。最終整備記録がなければ計算不能。
    nonisolated static func nextMaintenanceDueDate(lastMaintenanceDate: Date, intervalDays: Int, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: .day, value: intervalDays, to: lastMaintenanceDate)
    }

    /// ひとつの期限につき、リード日と期限日当日の2回ぶんの通知を作る。
    /// すでに過ぎた時刻のものは作らない（両方過ぎていれば空を返す）。
    ///
    /// **2件を最初から予約するのは、配信回数を再構築のタイミングに依存させないため。**
    /// 「予定日を過ぎていたら期限日へ寄せる」方式だと、リード日を過ぎたあとにアプリを
    /// 開いたかどうかで届く回数が変わる（開けば2回・開かなければ1回）。
    /// どちらの日時もdueDateとleadDaysだけから決まるので、何度組み直しても結果は同じ。
    nonisolated static func makeReminders(
        identifierPrefix: String,
        leadTitle: String,
        dueTitle: String,
        body: String,
        dueDate: Date,
        leadDays: Int,
        now: Date,
        calendar: Calendar
    ) -> [ReminderItem] {
        var reminders: [ReminderItem] = []
        // leadDaysが0だと期限日当日の通知と同じ日時になるため、リード日側は作らない。
        if leadDays > 0,
           let leadFire = scheduledFireDate(for: dueDate, leadDays: leadDays, calendar: calendar),
           leadFire > now {
            reminders.append(ReminderItem(
                identifier: "\(identifierPrefix)-lead",
                title: leadTitle,
                body: body,
                fireDate: leadFire
            ))
        }
        if let dueFire = scheduledFireDate(for: dueDate, leadDays: 0, calendar: calendar), dueFire > now {
            reminders.append(ReminderItem(
                identifier: "\(identifierPrefix)-due",
                title: dueTitle,
                body: body,
                fireDate: dueFire
            ))
        }
        return reminders
    }

    /// 通知対象を組み立てる。
    /// データの取得に失敗した場合はエラーを投げる。一部だけ欠けたリストを返すと、
    /// 呼び出し側がそれを正常な結果として既存の予約を置き換えてしまうため。
    static func buildItems(context: ModelContext, leadDays: Int, now: Date = Date(), calendar: Calendar = .current) throws -> [ReminderItem] {
        var items: [ReminderItem] = []

        for record in try fetchAll(InsuranceRecord.self, context: context) {
            guard record.type?.notification == true else { continue }
            guard record.bike?.archived != true else { continue }
            let bikeName = record.bike?.name ?? ""
            items += makeReminders(
                identifierPrefix: "insurance-\(record.id.uuidString)",
                leadTitle: "保険の満了が近づいています",
                dueTitle: "本日、保険が満了します",
                body: "\(bikeName) \(record.name)（\(dateString(record.finishDate))まで）",
                dueDate: record.finishDate,
                leadDays: leadDays,
                now: now,
                calendar: calendar
            )
        }

        for bike in try fetchAll(Bike.self, context: context) {
            guard !bike.archived, bike.inspectionNotification, let expiry = bike.inspectionExpiryDate else { continue }
            items += makeReminders(
                identifierPrefix: "inspection-\(bike.id.uuidString)",
                leadTitle: "車検満了が近づいています",
                dueTitle: "本日、車検が満了します",
                body: "\(bike.name)の車検満了日は\(dateString(expiry))",
                dueDate: expiry,
                leadDays: leadDays,
                now: now,
                calendar: calendar
            )
        }

        // MaintenancePartはバイクを持たない共有カタログで、複数のバイクが同じ部品を参照しうる。
        // 全記録から最新1件だけを採ると、直近に整備したバイク以外の次回目安日が消えるため、
        // 記録側のバイクごとに分けて目安日を求める。
        // 各部品の記録を1回ずつ見るため、走査量は整備記録の総件数に比例する。
        for part in try fetchAll(MaintenancePart.self, context: context) {
            guard part.notification, let intervalDays = part.intervalDays else { continue }
            for entry in latestRecordByBike(part: part) {
                guard !entry.bike.archived else { continue }
                guard let dueDate = nextMaintenanceDueDate(
                    lastMaintenanceDate: entry.record.maintenanceDate,
                    intervalDays: intervalDays,
                    calendar: calendar
                ) else {
                    logger.error("次回整備目安日の算出に失敗: intervalDays=\(intervalDays)")
                    continue
                }
                items += makeReminders(
                    identifierPrefix: "maintenancePart-\(part.id.uuidString)-\(entry.bike.id.uuidString)",
                    leadTitle: "整備時期が近づいています",
                    dueTitle: "本日、整備の目安日を迎えます",
                    body: "\(entry.bike.name) \(part.name)（目安 \(dateString(dueDate))）",
                    dueDate: dueDate,
                    leadDays: leadDays,
                    now: now,
                    calendar: calendar
                )
            }
        }

        // 保留できる通知には上限があり、超過分はOSに受け付けられない。
        // どれが落ちるかをOS任せにせず、配信日の近いものから残す。
        let sorted = items.sorted { $0.fireDate < $1.fireDate }
        if sorted.count > maxPendingRequests {
            logger.notice("保留通知の上限(\(maxPendingRequests))を超えたため、配信日の遠い\(sorted.count - maxPendingRequests)件を除外した")
        }
        return Array(sorted.prefix(maxPendingRequests))
    }

    /// 部品の整備記録をバイク単位にまとめ、それぞれの最新記録を返す。
    private static func latestRecordByBike(part: MaintenancePart) -> [(bike: Bike, record: MaintenanceRecord)] {
        var latestByBikeID: [UUID: (bike: Bike, record: MaintenanceRecord)] = [:]
        for record in part.records {
            guard let bike = record.bike else { continue }
            if let current = latestByBikeID[bike.id], current.record.maintenanceDate >= record.maintenanceDate { continue }
            latestByBikeID[bike.id] = (bike, record)
        }
        return Array(latestByBikeID.values)
    }

    /// 取得に失敗したらログを残したうえでエラーを投げ、呼び出し側に再構築を中止させる。
    /// 空配列を返して続行すると、失敗した種別だけが欠けたリストが「正常な結果」として扱われる。
    private static func fetchAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) throws -> [T] {
        do {
            return try context.fetch(FetchDescriptor<T>())
        } catch {
            logger.error("\(String(describing: type), privacy: .public)の取得に失敗: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    nonisolated private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}
