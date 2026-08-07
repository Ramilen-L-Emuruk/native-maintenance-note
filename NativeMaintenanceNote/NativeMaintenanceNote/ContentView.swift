//
//  ContentView.swift
//  NativeMaintenanceNote
//
//  Created by 西辻怜央 on 2026/08/06.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedBike: Bike?

    var body: some View {
        NavigationSplitView {
            BikeListView(selection: $selectedBike)
        } detail: {
            if let selectedBike, !selectedBike.isDeleted {
                BikeDetailView(bike: selectedBike)
            } else {
                ContentUnavailableView("バイクを選択してください", systemImage: "bicycle")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Bike.self, Maker.self, Shop.self], inMemory: true)
}
