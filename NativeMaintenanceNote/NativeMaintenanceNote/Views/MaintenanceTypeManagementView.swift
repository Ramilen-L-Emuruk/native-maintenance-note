//
//  MaintenanceTypeManagementView.swift
//  NativeMaintenanceNote
//
//  整備タイプ・部品はバイク横断のグローバルなマスタデータのため、
//  専用の管理画面として独立させている。
//

import SwiftUI
import SwiftData

struct MaintenanceTypeManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MaintenanceType.name) private var types: [MaintenanceType]
    @State private var isPresentingAddType = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(types) { type in
                    NavigationLink {
                        MaintenanceTypeDetailView(type: type)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(type.name)
                            Text("部品数: \(type.parts.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("整備タイプ管理")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
                ToolbarItem {
                    Button {
                        isPresentingAddType = true
                    } label: {
                        Label("タイプを追加", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddType) {
                AddMaintenanceTypeSheet()
            }
        }
    }
}
