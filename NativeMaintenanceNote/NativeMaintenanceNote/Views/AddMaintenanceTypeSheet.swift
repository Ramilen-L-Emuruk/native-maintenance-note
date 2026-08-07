//
//  AddMaintenanceTypeSheet.swift
//  NativeMaintenanceNote
//

import SwiftUI
import SwiftData

struct AddMaintenanceTypeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("整備タイプ名", text: $name)
            }
            .navigationTitle("整備タイプを追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let type = MaintenanceType(name: name)
                        modelContext.insert(type)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
