//
//  NativeMaintenanceNoteApp.swift
//  NativeMaintenanceNote
//
//  Created by 西辻怜央 on 2026/08/06.
//

import SwiftUI
import SwiftData

@main
struct NativeMaintenanceNoteApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // バックグラウンド再起動時にもSignificant-Change監視が再開されるよう、
        // 起動直後にシングルトンを生成しておく。
        _ = LocationLogger.shared
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Maker.self,
            Shop.self,
            MaintenanceType.self,
            MaintenancePart.self,
            InsuranceType.self,
            Bike.self,
            MaintenanceRecord.self,
            InsuranceRecord.self,
            RefuelRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            SeedData.seedIfNeeded(context: container.mainContext)
            // 起動直後の初回構築。前面復帰時の再構築（body側のonChange）とは役割が別で、
            // 同じ内容を二度組んでも識別子が同じなので上書きになるだけ。
            // 逆に初回構築を落とすと通知が一件も予約されないため、重複を許して両方残す。
            NotificationScheduler.rescheduleAll(context: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            // 端末の設定アプリで通知を許可してから戻ってきた場合、アプリは再起動されない。
            // 前面復帰のたびに組み直すことで、許可の後付けを取りこぼさないようにする。
            // 許可状態の変化だけを条件に絞らないのは、変化を検知し損ねたときに取りこぼすため。
            // 予約内容は現在のデータだけから決まるので、何度実行しても同じ結果に収束する。
            guard newPhase == .active else { return }
            NotificationScheduler.rescheduleAll(context: sharedModelContainer.mainContext)
        }
    }
}
