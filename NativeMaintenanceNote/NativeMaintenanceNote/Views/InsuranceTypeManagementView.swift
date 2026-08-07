//
//  InsuranceTypeManagementView.swift
//  NativeMaintenanceNote
//
//  保険タイプはバイク横断のグローバルなマスタデータのため、
//  専用の管理画面として独立させている。
//

import SwiftUI
import SwiftData

struct InsuranceTypeManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \InsuranceType.name) private var types: [InsuranceType]
    @State private var activeSheet: TypeSheet?

    var body: some View {
        NavigationStack {
            List {
                ForEach(types) { type in
                    Button {
                        activeSheet = .edit(type)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(type.name)
                                Text(type.notification ? "通知: 有効" : "通知: 無効")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("保険タイプ管理")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
                ToolbarItem {
                    Button {
                        activeSheet = .new
                    } label: {
                        Label("タイプを追加", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                NavigationStack {
                    switch sheet {
                    case .new:
                        InsuranceTypeFormView(type: nil)
                    case .edit(let type):
                        InsuranceTypeFormView(type: type)
                    }
                }
            }
        }
    }
}

private enum TypeSheet: Identifiable {
    case new
    case edit(InsuranceType)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let type): return type.id.uuidString
        }
    }
}
