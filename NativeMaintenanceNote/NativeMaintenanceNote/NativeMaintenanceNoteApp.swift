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
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            SeedData.seedIfNeeded(context: container.mainContext)
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
    }
}
