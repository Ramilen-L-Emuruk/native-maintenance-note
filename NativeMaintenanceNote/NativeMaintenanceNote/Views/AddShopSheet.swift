//
//  AddShopSheet.swift
//  NativeMaintenanceNote
//

import SwiftUI
import SwiftData

struct AddShopSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""

    let onAdd: (Shop) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("ショップ名", text: $name)
                TextField("住所", text: $address)
            }
            .navigationTitle("購入店を追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let shop = Shop(name: name, address: address)
                        modelContext.insert(shop)
                        onAdd(shop)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
