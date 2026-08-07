//
//  ContentView.swift
//  NativeMaintenanceNote
//
//  Created by 西辻怜央 on 2026/08/06.
//
//  Phase 0時点の暫定表示。シードデータが投入されていることを確認するための
//  デバッグ用リストで、Phase 1でBikeベースのNavigationSplitViewに置き換える。
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Maker.name) private var makers: [Maker]
    @Query(sort: \MaintenanceType.name) private var maintenanceTypes: [MaintenanceType]
    @Query(sort: \InsuranceType.name) private var insuranceTypes: [InsuranceType]

    var body: some View {
        NavigationStack {
            List {
                Section("メーカー（\(makers.count)件）") {
                    ForEach(makers) { maker in
                        Text(maker.name)
                    }
                }

                Section("整備タイプ（\(maintenanceTypes.count)件）") {
                    ForEach(maintenanceTypes) { type in
                        VStack(alignment: .leading) {
                            Text(type.name)
                            Text("部品数: \(type.parts.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("保険タイプ（\(insuranceTypes.count)件）") {
                    ForEach(insuranceTypes) { type in
                        Text(type.name)
                    }
                }
            }
            .navigationTitle("シードデータ確認")
            .toolbar {
                ToolbarItem {
                    NavigationLink {
                        LocationVerificationView()
                    } label: {
                        Label("GPS検証", systemImage: "location")
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Maker.self, MaintenanceType.self, MaintenancePart.self, InsuranceType.self], inMemory: true)
}
