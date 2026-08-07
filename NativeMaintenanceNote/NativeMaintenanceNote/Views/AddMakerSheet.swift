//
//  AddMakerSheet.swift
//  NativeMaintenanceNote
//

import SwiftUI
import SwiftData

struct AddMakerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""

    let onAdd: (Maker) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("メーカー名", text: $name)
            }
            .navigationTitle("メーカーを追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let maker = Maker(name: name)
                        modelContext.insert(maker)
                        onAdd(maker)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
